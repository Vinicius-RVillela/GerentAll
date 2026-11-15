using Microsoft.EntityFrameworkCore;

namespace Mercadinho.Infrastructure.Persistence;

/// <summary>
/// Contexto do Entity Framework. As entidades (Produto, Movimentacao...)
/// entram aqui a partir da Fase 1.
/// </summary>
public class AppDbContext(DbContextOptions<AppDbContext> options) : DbContext(options)
{
    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        // Aplica todas as classes IEntityTypeConfiguration<T> deste projeto.
        modelBuilder.ApplyConfigurationsFromAssembly(typeof(AppDbContext).Assembly);
    }
}
