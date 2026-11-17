using Mercadinho.Domain.Entities;
using Mercadinho.Domain.Enums;
using Mercadinho.Domain.ValueObjects;

namespace Mercadinho.Domain.Tests;

public class ProdutoTests
{
    private static Produto NovoProduto() =>
        new("Arroz 5kg", Unidade.UN, precoCusto: 20m, precoVenda: 27.90m);

    [Fact]
    public void Cria_produto_valido_e_ativo()
    {
        var p = new Produto("  Leite integral  ", Unidade.CX, 30m, 42m,
            CodigoBarras.Criar("7891000100103"), "Caixa com 12", estoqueMinimo: 2);

        Assert.Equal("Leite integral", p.Nome);   // espaços removidos
        Assert.Equal(Unidade.CX, p.Unidade);
        Assert.Equal("7891000100103", p.CodigoBarras?.Valor);
        Assert.True(p.Ativo);
        Assert.NotEqual(Guid.Empty, p.Id);
    }

    [Theory]
    [InlineData("")]
    [InlineData("   ")]
    public void Construtor_rejeita_nome_vazio(string nome)
    {
        Assert.Throws<ArgumentException>(() => new Produto(nome, Unidade.UN, 1m, 2m));
    }

    [Fact]
    public void Rejeita_nome_maior_que_o_limite()
    {
        var p = NovoProduto();
        Assert.Throws<ArgumentException>(() => p.Renomear(new string('A', Produto.TamanhoMaximoNome + 1)));
    }

    [Theory]
    [InlineData(-1, 10)]   // custo negativo
    [InlineData(5, 0)]     // venda zero
    [InlineData(5, -3)]    // venda negativa
    public void Rejeita_precos_invalidos(decimal custo, decimal venda)
    {
        Assert.Throws<ArgumentException>(() => new Produto("Feijão", Unidade.UN, custo, venda));
    }

    [Fact]
    public void Preco_invalido_nao_altera_os_precos_atuais()
    {
        var p = NovoProduto();
        Assert.Throws<ArgumentException>(() => p.DefinirPrecos(10m, 0m));
        Assert.Equal(20m, p.PrecoCusto);
        Assert.Equal(27.90m, p.PrecoVenda);
    }

    [Fact]
    public void Calcula_a_margem_sobre_o_custo()
    {
        var p = new Produto("Café", Unidade.UN, 10m, 15m);
        Assert.Equal(50m, p.MargemPercentual);
    }

    [Fact]
    public void Rejeita_unidade_que_nao_existe()
    {
        Assert.Throws<ArgumentException>(() => new Produto("Sal", (Unidade)99, 1m, 2m));
    }

    [Fact]
    public void Desativar_e_ativar()
    {
        var p = NovoProduto();
        p.Desativar();
        Assert.False(p.Ativo);
        p.Ativar();
        Assert.True(p.Ativo);
    }

    [Fact]
    public void Descricao_em_branco_vira_null()
    {
        var p = NovoProduto();
        p.AlterarDescricao("   ");
        Assert.Null(p.Descricao);
    }
}
