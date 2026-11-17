using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;

namespace Mercadinho.Api.Tests;

/// <summary>
/// Sobe a API em memória para os testes. Como o repositório não guarda nenhuma
/// conexão com o banco, aqui entra uma de mentira (sem senha): os testes de
/// /health/live não chegam a abrir conexão com o PostgreSQL.
/// </summary>
public class ApiFactory : WebApplicationFactory<Program>
{
    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseSetting("ConnectionStrings:Default",
            "Host=localhost;Port=5432;Database=gerentall_teste;Username=teste");
    }
}
