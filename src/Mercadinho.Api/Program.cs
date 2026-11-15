using Mercadinho.Infrastructure;
using Mercadinho.Infrastructure.Persistence;
using Microsoft.AspNetCore.Diagnostics.HealthChecks;

var builder = WebApplication.CreateBuilder(args);

var connectionString = builder.Configuration.GetConnectionString("Default")
    ?? throw new InvalidOperationException("ConnectionStrings:Default não configurada.");

builder.Services.AddInfrastructure(connectionString);
builder.Services.AddControllers();
builder.Services.AddOpenApi();

builder.Services.AddHealthChecks()
    .AddDbContextCheck<AppDbContext>("banco", tags: ["ready"]);

var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();                       // /openapi/v1.json
    app.UseSwaggerUI(o => o.SwaggerEndpoint("/openapi/v1.json", "Mercadinho API v1"));
}

// /health/live: a API está de pé (não consulta o banco).
app.MapHealthChecks("/health/live", new HealthCheckOptions { Predicate = _ => false });
// /health/ready: a API consegue falar com o PostgreSQL.
app.MapHealthChecks("/health/ready", new HealthCheckOptions { Predicate = c => c.Tags.Contains("ready") });

app.UseAuthorization();
app.MapControllers();

app.Run();

// Permite que os testes de integração usem WebApplicationFactory<Program>.
public partial class Program;
