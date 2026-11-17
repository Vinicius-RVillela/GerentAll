using Mercadinho.Domain.Entities;
using Mercadinho.Domain.Enums;

namespace Mercadinho.Domain.Tests;

public class UsuarioTests
{
    // Um texto qualquer no formato de hash. Nos testes de domínio não existe senha de verdade.
    private const string Hash = "$2a$11$abcdefghijklmnopqrstuuJ8m0mX1nC3YQhTn2c1o0sHk4lVq9wW";
    private const string OutroHash = "$2a$11$zyxwvutsrqponmlkjihgfeJ8m0mX1nC3YQhTn2c1o0sHk4lVq9wW";
    private static readonly DateTime Agora = new(2026, 11, 17, 12, 0, 0, DateTimeKind.Utc);

    private static Usuario NovoUsuario(Perfil perfil = Perfil.Operador) =>
        new("Ana Souza", "ana@loja.com", Hash, perfil);

    // ---------------- Criação e dados ----------------

    [Fact]
    public void Cria_usuario_ativo_com_email_normalizado()
    {
        var u = new Usuario("  Ana Souza ", "  Ana@Loja.COM ", Hash, Perfil.Gerente);

        Assert.Equal("Ana Souza", u.Nome);
        Assert.Equal("ana@loja.com", u.Email);
        Assert.Equal(Perfil.Gerente, u.Perfil);
        Assert.True(u.Ativo);
        Assert.Equal(0, u.TentativasFalhas);
        Assert.Null(u.UltimoAcessoEm);
    }

    [Theory]
    [InlineData("")]
    [InlineData("ana")]
    [InlineData("ana@")]
    [InlineData("@loja.com")]
    [InlineData("ana@loja")]                 // sem ponto no domínio
    [InlineData("ana souza@loja.com")]       // espaço no meio
    [InlineData("Ana <ana@loja.com>")]       // formato com nome
    public void Rejeita_email_invalido(string email)
    {
        Assert.Throws<ArgumentException>(() => new Usuario("Ana", email, Hash, Perfil.Operador));
    }

    [Fact]
    public void Rejeita_nome_vazio()
    {
        Assert.Throws<ArgumentException>(() => new Usuario("   ", "ana@loja.com", Hash, Perfil.Operador));
    }

    [Fact]
    public void Rejeita_perfil_que_nao_existe()
    {
        Assert.Throws<ArgumentException>(() => new Usuario("Ana", "ana@loja.com", Hash, (Perfil)99));
    }

    // ---------------- Senha ----------------

    [Theory]
    [InlineData("")]
    [InlineData("   ")]
    [InlineData("hash com espaco")]
    public void Rejeita_hash_invalido(string hash)
    {
        Assert.Throws<ArgumentException>(() => new Usuario("Ana", "ana@loja.com", hash, Perfil.Operador));
    }

    [Fact]
    public void Mensagem_de_erro_nunca_mostra_o_hash()
    {
        var hashComEspaco = "segredo segredo";
        var erro = Assert.Throws<ArgumentException>(
            () => new Usuario("Ana", "ana@loja.com", hashComEspaco, Perfil.Operador));
        Assert.DoesNotContain("segredo", erro.Message);
    }

    [Fact]
    public void ToString_nao_mostra_o_hash()
    {
        var u = NovoUsuario();
        Assert.DoesNotContain(Hash, u.ToString());
    }

    [Fact]
    public void Trocar_senha_derruba_logins_abertos_e_libera_bloqueio()
    {
        var u = NovoUsuario();
        var carimboAntes = u.CarimboSeguranca;
        for (int i = 0; i < Usuario.TentativasAntesDoBloqueio; i++) u.RegistrarFalhaDeLogin(Agora);
        Assert.True(u.EstaBloqueado(Agora));

        u.DefinirSenhaHash(OutroHash);

        Assert.NotEqual(carimboAntes, u.CarimboSeguranca);
        Assert.False(u.EstaBloqueado(Agora));
        Assert.Equal(0, u.TentativasFalhas);
    }

    // ---------------- Perfil e ativação ----------------

    [Fact]
    public void Mudar_perfil_troca_o_carimbo()
    {
        var u = NovoUsuario(Perfil.Gerente);
        var antes = u.CarimboSeguranca;

        u.AlterarPerfil(Perfil.Operador);

        Assert.Equal(Perfil.Operador, u.Perfil);
        Assert.NotEqual(antes, u.CarimboSeguranca);
    }

    [Fact]
    public void Manter_o_mesmo_perfil_nao_troca_o_carimbo()
    {
        var u = NovoUsuario(Perfil.Gerente);
        var antes = u.CarimboSeguranca;
        u.AlterarPerfil(Perfil.Gerente);
        Assert.Equal(antes, u.CarimboSeguranca);
    }

    [Fact]
    public void Desativado_nao_pode_entrar_e_tem_carimbo_novo()
    {
        var u = NovoUsuario();
        var antes = u.CarimboSeguranca;

        u.Desativar();

        Assert.False(u.PodeEntrar(Agora));
        Assert.NotEqual(antes, u.CarimboSeguranca);
        Assert.Throws<InvalidOperationException>(() => u.RegistrarLoginComSucesso(Agora));
    }

    // ---------------- Força bruta ----------------

    [Fact]
    public void Quatro_erros_ainda_nao_bloqueiam()
    {
        var u = NovoUsuario();
        for (int i = 0; i < Usuario.TentativasAntesDoBloqueio - 1; i++) u.RegistrarFalhaDeLogin(Agora);
        Assert.True(u.PodeEntrar(Agora));
    }

    [Fact]
    public void Cinco_erros_bloqueiam_por_15_minutos()
    {
        var u = NovoUsuario();
        for (int i = 0; i < Usuario.TentativasAntesDoBloqueio; i++) u.RegistrarFalhaDeLogin(Agora);

        Assert.False(u.PodeEntrar(Agora));
        Assert.False(u.PodeEntrar(Agora.AddMinutes(14)));
        Assert.True(u.PodeEntrar(Agora.AddMinutes(15)));     // o bloqueio venceu
    }

    [Fact]
    public void Depois_que_o_bloqueio_vence_a_contagem_recomeca()
    {
        var u = NovoUsuario();
        for (int i = 0; i < Usuario.TentativasAntesDoBloqueio; i++) u.RegistrarFalhaDeLogin(Agora);

        u.RegistrarFalhaDeLogin(Agora.AddMinutes(20));       // 1 erro depois do bloqueio

        Assert.Equal(1, u.TentativasFalhas);
        Assert.True(u.PodeEntrar(Agora.AddMinutes(20)));
    }

    [Fact]
    public void Login_certo_zera_os_erros_e_anota_o_acesso()
    {
        var u = NovoUsuario();
        u.RegistrarFalhaDeLogin(Agora);
        u.RegistrarFalhaDeLogin(Agora);

        u.RegistrarLoginComSucesso(Agora.AddMinutes(1));

        Assert.Equal(0, u.TentativasFalhas);
        Assert.Equal(Agora.AddMinutes(1), u.UltimoAcessoEm);
    }

    [Fact]
    public void Bloqueado_nao_consegue_login_mesmo_com_senha_certa()
    {
        var u = NovoUsuario();
        for (int i = 0; i < Usuario.TentativasAntesDoBloqueio; i++) u.RegistrarFalhaDeLogin(Agora);
        Assert.Throws<InvalidOperationException>(() => u.RegistrarLoginComSucesso(Agora.AddMinutes(1)));
    }
}
