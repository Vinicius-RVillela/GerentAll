using Mercadinho.Domain.ValueObjects;

namespace Mercadinho.Domain.Tests;

public class CodigoBarrasTests
{
    [Theory]
    [InlineData("7891000100103")]
    [InlineData("4006381333931")]
    [InlineData(" 7891000100103 ")] // espaços nas pontas são ignorados
    public void Aceita_ean13_valido(string texto)
    {
        Assert.True(CodigoBarras.TentarCriar(texto, out var codigo));
        Assert.Equal(texto.Trim(), codigo.Valor);
    }

    [Theory]
    [InlineData("7891000100104")] // dígito verificador errado
    [InlineData("789100010010")]  // 12 dígitos
    [InlineData("78910001001A3")] // letra
    [InlineData("")]
    [InlineData(null)]
    public void Rejeita_ean13_invalido(string? texto)
    {
        Assert.False(CodigoBarras.TentarCriar(texto, out _));
    }

    [Fact]
    public void Criar_lanca_excecao_quando_invalido()
    {
        Assert.Throws<ArgumentException>(() => CodigoBarras.Criar("123"));
    }
}
