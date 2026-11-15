# Mercadinho — Controle de Estoque

Sistema de retaguarda para mercadinhos: cadastro de produtos, controle de
estoque por lote e validade, importação de NF-e por XML e relatórios de venda
com projeção. Roda em **Linux e Windows 10/11**.

> 🚧 Em desenvolvimento — fase atual: **0 (fundação)**. Veja o
> [plano completo](docs/PLANO_MVP.md).

## Arquitetura

```
Mercadinho.Desktop (Avalonia)  ──HTTP──▶  Mercadinho.Api (ASP.NET Core)
                                               │
                                     Application (casos de uso)
                                               │
                                   Domain (regras, sem dependências)
                                               │
                              Infrastructure (EF Core) ──▶ PostgreSQL
```

| Camada | Tecnologia |
|---|---|
| API | ASP.NET Core (.NET 10), OpenAPI/Swagger |
| Banco | PostgreSQL 17 + Entity Framework Core |
| Desktop | Avalonia UI 12 + MVVM (CommunityToolkit.Mvvm) |
| Testes | xUnit, WebApplicationFactory |
| Infra | Docker Compose, GitHub Actions |

## Como rodar

### Com Docker (API + banco)

```bash
cp .env.example .env      # ajuste a senha
docker compose up --build
```

- Saúde da API: http://localhost:8080/health/live
- Conexão com o banco: http://localhost:8080/health/ready
- Swagger: http://localhost:8080/swagger

### Sem Docker (desenvolvimento)

Requer .NET SDK 10 e um PostgreSQL local (ajuste
`src/Mercadinho.Api/appsettings.json`).

```bash
dotnet run --project src/Mercadinho.Api
dotnet run --project src/Mercadinho.Desktop
```

### Testes

```bash
dotnet test
```

## Estrutura

```
src/
  Mercadinho.Domain/          entidades e regras de negócio
  Mercadinho.Application/     casos de uso
  Mercadinho.Infrastructure/  banco de dados (EF Core + Npgsql)
  Mercadinho.Api/             API REST
  Mercadinho.Desktop/         aplicativo desktop (Avalonia)
tests/
  Mercadinho.Domain.Tests/
  Mercadinho.Api.Tests/
docs/
  PLANO_MVP.md
```
