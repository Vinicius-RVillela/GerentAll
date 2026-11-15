namespace Mercadinho.Domain.ValueObjects;

/// <summary>
/// Código de barras EAN-13 (o padrão dos produtos de mercado no Brasil, prefixo 789/790).
/// Só pode ser criado se o dígito verificador estiver correto.
/// </summary>
public readonly record struct CodigoBarras
{
    public string Valor { get; }

    private CodigoBarras(string valor) => Valor = valor;

    public static bool TentarCriar(string? texto, out CodigoBarras codigo)
    {
        codigo = default;
        var limpo = texto?.Trim();
        if (limpo is null || limpo.Length != 13 || !limpo.All(char.IsAsciiDigit)) return false;
        if (CalcularDigito(limpo[..12]) != limpo[12] - '0') return false;

        codigo = new CodigoBarras(limpo);
        return true;
    }

    public static CodigoBarras Criar(string texto) =>
        TentarCriar(texto, out var codigo)
            ? codigo
            : throw new ArgumentException($"EAN-13 inválido: '{texto}'.", nameof(texto));

    /// <summary>Pesos 1 e 3 alternados; o dígito completa a soma até o próximo múltiplo de 10.</summary>
    private static int CalcularDigito(string doze)
    {
        var soma = 0;
        for (var i = 0; i < 12; i++)
            soma += (doze[i] - '0') * (i % 2 == 0 ? 1 : 3);
        return (10 - soma % 10) % 10;
    }

    public override string ToString() => Valor;
}
