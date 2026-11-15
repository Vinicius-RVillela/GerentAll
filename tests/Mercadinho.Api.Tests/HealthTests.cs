using System.Net;
using Microsoft.AspNetCore.Mvc.Testing;

namespace Mercadinho.Api.Tests;

public class HealthTests(WebApplicationFactory<Program> factory) : IClassFixture<WebApplicationFactory<Program>>
{
    [Fact]
    public async Task Health_live_responde_200_sem_precisar_do_banco()
    {
        var client = factory.CreateClient();

        var resposta = await client.GetAsync("/health/live");

        Assert.Equal(HttpStatusCode.OK, resposta.StatusCode);
    }
}
