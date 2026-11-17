using Mercadinho.Domain.Enums;
using Mercadinho.Domain.ValueObjects;

namespace Mercadinho.Domain.Entities;

/// <summary>
/// Produto vendido no mercadinho.
/// O saldo do estoque NÃO fica aqui: ele é a soma das movimentações (Fase 2).
/// </summary>
public class Produto
{
    public const int TamanhoMaximoNome = 120;

    public Guid Id { get; private set; } = Guid.CreateVersion7();
    public string Nome { get; private set; } = null!;
    public string? Descricao { get; private set; }
    public CodigoBarras? CodigoBarras { get; private set; }
    public Unidade Unidade { get; private set; }
    public decimal PrecoCusto { get; private set; }
    public decimal PrecoVenda { get; private set; }
    public decimal EstoqueMinimo { get; private set; }
    public bool Ativo { get; private set; } = true;

    /// <summary>Margem sobre o custo, em %. Ex.: custo 10 e venda 15 = 50%.</summary>
    public decimal MargemPercentual =>
        PrecoCusto == 0 ? 0 : Math.Round((PrecoVenda - PrecoCusto) / PrecoCusto * 100, 2);

    // Usado só pelo Entity Framework para montar o objeto a partir do banco.
    private Produto() { }

    public Produto(
        string nome,
        Unidade unidade,
        decimal precoCusto,
        decimal precoVenda,
        CodigoBarras? codigoBarras = null,
        string? descricao = null,
        decimal estoqueMinimo = 0)
    {
        // O construtor usa os mesmos métodos de alteração: as regras ficam num lugar só.
        Renomear(nome);
        AlterarDescricao(descricao);
        DefinirUnidade(unidade);
        DefinirPrecos(precoCusto, precoVenda);
        DefinirEstoqueMinimo(estoqueMinimo);
        CodigoBarras = codigoBarras;
    }

    public void Renomear(string nome)
    {
        if (string.IsNullOrWhiteSpace(nome))
            throw new ArgumentException("O nome não pode ficar vazio.", nameof(nome));

        var limpo = nome.Trim();
        if (limpo.Length > TamanhoMaximoNome)
            throw new ArgumentException($"O nome pode ter no máximo {TamanhoMaximoNome} caracteres.", nameof(nome));

        Nome = limpo;
    }

    public void AlterarDescricao(string? descricao) =>
        Descricao = string.IsNullOrWhiteSpace(descricao) ? null : descricao.Trim();

    public void DefinirUnidade(Unidade unidade)
    {
        if (!Enum.IsDefined(unidade))
            throw new ArgumentException($"Unidade inválida: {unidade}.", nameof(unidade));
        Unidade = unidade;
    }

    public void DefinirPrecos(decimal custo, decimal venda)
    {
        if (custo < 0)
            throw new ArgumentException("O preço de custo não pode ser negativo.", nameof(custo));
        if (venda <= 0)
            throw new ArgumentException("O preço de venda precisa ser maior que zero.", nameof(venda));

        PrecoCusto = custo;
        PrecoVenda = venda;
    }

    public void DefinirCodigoBarras(CodigoBarras? codigo) => CodigoBarras = codigo;

    public void DefinirEstoqueMinimo(decimal minimo)
    {
        if (minimo < 0)
            throw new ArgumentException("O estoque mínimo não pode ser negativo.", nameof(minimo));
        EstoqueMinimo = minimo;
    }

    /// <summary>Produto fora de linha: some das buscas, mas o histórico continua.</summary>
    public void Desativar() => Ativo = false;

    public void Ativar() => Ativo = true;
}
