using System.Net.Mail;
using Mercadinho.Domain.Enums;

namespace Mercadinho.Domain.Entities;

/// <summary>
/// Pessoa que usa o sistema (Admin, Gerente ou Operador).
///
/// SEGURANÇA, regra de ouro: esta classe NUNCA recebe nem guarda a senha.
/// Ela só guarda o HASH (uma "impressão digital" de mão única da senha).
/// Quem transforma senha em hash é um serviço fora do domínio (passo 4),
/// assim o domínio nem sabe qual algoritmo é usado.
///
/// Por que é "class" e não "record": um record gera ToString() automático
/// com TODAS as propriedades, e o SenhaHash acabaria aparecendo em logs.
/// </summary>
public class Usuario
{
    public const int TamanhoMaximoNome = 120;
    public const int TamanhoMaximoEmail = 254;      // limite do padrão de e-mail (RFC 5321)
    public const int TamanhoMaximoHash = 500;
    public const int TentativasAntesDoBloqueio = 5;
    public static readonly TimeSpan TempoDeBloqueio = TimeSpan.FromMinutes(15);

    public Guid Id { get; private set; } = Guid.CreateVersion7();
    public string Nome { get; private set; } = null!;
    public string Email { get; private set; } = null!;
    public string SenhaHash { get; private set; } = null!;
    public Perfil Perfil { get; private set; }
    public bool Ativo { get; private set; } = true;
    public DateTime CriadoEm { get; private set; } = DateTime.UtcNow;

    /// <summary>Último login que deu certo (UTC). null = nunca entrou.</summary>
    public DateTime? UltimoAcessoEm { get; private set; }

    /// <summary>Senhas erradas seguidas desde o último login certo.</summary>
    public int TentativasFalhas { get; private set; }

    /// <summary>Até quando o login fica travado depois de muitas senhas erradas (UTC).</summary>
    public DateTime? BloqueadoAte { get; private set; }

    /// <summary>
    /// "Carimbo de segurança": muda sempre que algo sensível muda (senha, perfil,
    /// desativação). O token de login guarda o carimbo da hora em que foi criado;
    /// se o carimbo do usuário mudou, o token antigo deixa de valer.
    /// Exemplo: o gerente é rebaixado a operador e sai na hora de todos os PCs.
    /// </summary>
    public Guid CarimboSeguranca { get; private set; } = Guid.NewGuid();

    // Usado só pelo Entity Framework para montar o objeto a partir do banco.
    private Usuario() { }

    public Usuario(string nome, string email, string senhaHash, Perfil perfil)
    {
        // Mesmos métodos usados nas alterações: cada regra fica num lugar só.
        Renomear(nome);
        AlterarEmail(email);
        DefinirSenhaHash(senhaHash);
        AlterarPerfil(perfil);
    }

    // ------------------------------------------------------------------
    // Dados cadastrais
    // ------------------------------------------------------------------

    public void Renomear(string nome)
    {
        if (string.IsNullOrWhiteSpace(nome))
            throw new ArgumentException("O nome não pode ficar vazio.", nameof(nome));

        var limpo = nome.Trim();
        if (limpo.Length > TamanhoMaximoNome)
            throw new ArgumentException($"O nome pode ter no máximo {TamanhoMaximoNome} caracteres.", nameof(nome));

        Nome = limpo;
    }

    /// <summary>
    /// Guarda o e-mail sempre em minúsculo e sem espaços nas pontas.
    /// Assim "Ana@Loja.com" e "ana@loja.com " são a MESMA conta, e ninguém
    /// cria uma segunda conta só mudando maiúsculas.
    /// </summary>
    public void AlterarEmail(string email)
    {
        var normalizado = NormalizarEmail(email);
        if (!EmailValido(normalizado))
            throw new ArgumentException("E-mail inválido.", nameof(email));

        Email = normalizado;
    }

    public void AlterarPerfil(Perfil perfil)
    {
        if (!Enum.IsDefined(perfil))
            throw new ArgumentException($"Perfil inválido: {perfil}.", nameof(perfil));

        if (Perfil != perfil && Perfil != default)
            TrocarCarimbo();   // mudou o poder do usuário: derruba os logins abertos

        Perfil = perfil;
    }

    // ------------------------------------------------------------------
    // Senha (só o hash)
    // ------------------------------------------------------------------

    /// <summary>
    /// Recebe o HASH já pronto (nunca a senha). Trocar a senha também
    /// derruba os logins abertos e libera um bloqueio.
    /// </summary>
    public void DefinirSenhaHash(string senhaHash)
    {
        if (string.IsNullOrWhiteSpace(senhaHash))
            throw new ArgumentException("O hash da senha não pode ficar vazio.", nameof(senhaHash));
        if (senhaHash.Length > TamanhoMaximoHash || senhaHash.Any(char.IsWhiteSpace))
            // Mensagem genérica de propósito: nunca coloque o hash na mensagem de erro.
            throw new ArgumentException("Hash de senha em formato inválido.", nameof(senhaHash));

        var trocou = SenhaHash is not null;
        SenhaHash = senhaHash;

        if (trocou)
        {
            TrocarCarimbo();
            TentativasFalhas = 0;
            BloqueadoAte = null;
        }
    }

    // ------------------------------------------------------------------
    // Login: proteção contra "chute" de senha (força bruta)
    // ------------------------------------------------------------------
    // O horário "agora" vem de fora (parâmetro) em vez de DateTime.UtcNow aqui
    // dentro. Assim os testes conseguem "viajar no tempo" sem esperar 15 minutos.

    /// <summary>Pode tentar entrar? Precisa estar ativo e não bloqueado.</summary>
    public bool PodeEntrar(DateTime agoraUtc) => Ativo && !EstaBloqueado(agoraUtc);

    public bool EstaBloqueado(DateTime agoraUtc) => BloqueadoAte is { } ate && agoraUtc < ate;

    /// <summary>Senha errada: conta a tentativa e trava após 5 erros seguidos.</summary>
    public void RegistrarFalhaDeLogin(DateTime agoraUtc)
    {
        // Um bloqueio que já venceu recomeça a contagem do zero.
        if (BloqueadoAte is { } ate && agoraUtc >= ate)
        {
            BloqueadoAte = null;
            TentativasFalhas = 0;
        }

        TentativasFalhas++;
        if (TentativasFalhas >= TentativasAntesDoBloqueio)
            BloqueadoAte = agoraUtc + TempoDeBloqueio;
    }

    /// <summary>Login certo: zera os erros e anota o acesso.</summary>
    public void RegistrarLoginComSucesso(DateTime agoraUtc)
    {
        if (!PodeEntrar(agoraUtc))
            throw new InvalidOperationException("Este usuário não pode entrar agora.");

        TentativasFalhas = 0;
        BloqueadoAte = null;
        UltimoAcessoEm = agoraUtc;
    }

    // ------------------------------------------------------------------
    // Ativação
    // ------------------------------------------------------------------

    /// <summary>
    /// Desativa em vez de apagar: as movimentações de estoque continuam
    /// mostrando quem fez o quê (rastro de auditoria).
    /// </summary>
    public void Desativar()
    {
        if (!Ativo) return;
        Ativo = false;
        TrocarCarimbo();   // sai na hora de todos os computadores
    }

    public void Ativar() => Ativo = true;

    // ------------------------------------------------------------------
    // Ajudantes
    // ------------------------------------------------------------------

    /// <summary>Usado também na busca do login: normalize ANTES de procurar no banco.</summary>
    public static string NormalizarEmail(string? email) =>
        (email ?? string.Empty).Trim().ToLowerInvariant();

    private static bool EmailValido(string email)
    {
        if (email.Length == 0 || email.Length > TamanhoMaximoEmail) return false;
        if (email.Any(char.IsWhiteSpace)) return false;

        // MailAddress confere o formato. Comparar o Address com o texto barra
        // formatos como "Ana <ana@x.com>", que o MailAddress também aceitaria.
        return MailAddress.TryCreate(email, out var endereco)
               && endereco.Address == email
               && endereco.Host.Contains('.');
    }

    private void TrocarCarimbo() => CarimboSeguranca = Guid.NewGuid();

    /// <summary>Nunca mostra o hash: seguro para aparecer em log.</summary>
    public override string ToString() => $"Usuario {Id} ({Email}, {Perfil})";
}
