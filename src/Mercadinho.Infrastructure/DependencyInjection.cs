using Mercadinho.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace Mercadinho.Infrastructure;

public static class DependencyInjection
{
    /// <summary>Registra banco de dados e serviços de infraestrutura.</summary>
    public static IServiceCollection AddInfrastructure(this IServiceCollection services, string connectionString)
    {
        // MariaDB/MySQL pelo provedor oficial da Oracle (MySql.EntityFrameworkCore).
        services.AddDbContext<AppDbContext>(options => options.UseMySQL(connectionString));
        return services;
    }
}
