namespace Mercadinho.Domain.Enums;

/// <summary>Como o produto é vendido e contado no estoque.</summary>
public enum Unidade
{
    /// <summary>Unidade (ex.: 1 lata de refrigerante).</summary>
    UN = 1,
    /// <summary>Quilograma (ex.: 0,350 kg de queijo).</summary>
    KG = 2,
    /// <summary>Caixa (ex.: 1 caixa com 12 leites).</summary>
    CX = 3,
}
