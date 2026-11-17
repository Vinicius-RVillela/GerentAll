namespace Mercadinho.Domain.Enums;

/// <summary>
/// O que cada usuário pode fazer no sistema (controle de acesso por perfil).
/// Os números são fixos de propósito: é o número que vai para o banco.
/// Nunca reaproveite nem troque um número existente; só acrescente novos.
/// </summary>
public enum Perfil
{
    /// <summary>
    /// Dono do sistema: cadastra usuários, muda perfis, faz backup e
    /// acessa as configurações da loja.
    /// </summary>
    Admin = 1,

    /// <summary>
    /// Gerente da loja: tudo do Operador, mais ajuste de estoque,
    /// importação de notas e relatórios.
    /// </summary>
    Gerente = 2,

    /// <summary>
    /// Dia a dia: consulta produtos, registra vendas e avarias.
    /// Não pode ajustar estoque nem mexer em usuários.
    /// </summary>
    Operador = 3,
}
