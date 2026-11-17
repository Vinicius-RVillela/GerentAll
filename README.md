# GerentAll — Controle de Estoque para Mercadinhos

Sistema de retaguarda para mercadinhos: cadastro de produtos, controle de
estoque por lote e validade, importação de NF-e por XML e relatórios de venda
com projeção. Roda em **Linux e Windows 10/11**.

> 🚧 Em desenvolvimento — fase atual: **0 (fundação)**. Veja o
> [plano completo](docs/PLANO_MVP.md).

> **Sobre o nome:** o produto se chama **GerentAll**. No código, os projetos e
> namespaces usam **Mercadinho** (`Mercadinho.Api`, `Mercadinho.Domain`...),
> porque descrevem o domínio do sistema, que é o mercadinho.

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

O PostgreSQL só aceita conexões deste computador (`127.0.0.1:5432`).

- Saúde da API: http://localhost:8080/health/live
- Conexão com o banco: http://localhost:8080/health/ready
- Swagger: http://localhost:8080/swagger

### Sem Docker (desenvolvimento)

Requer .NET SDK 10 e um PostgreSQL. O mais simples é subir só o banco do
Docker:

```bash
docker compose up -d db
```

A conexão com o banco **não fica no repositório**. Ela é guardada com o
[user-secrets](https://learn.microsoft.com/aspnet/core/security/app-secrets)
do .NET, fora da pasta do projeto. Configure uma vez, trocando `SUA_SENHA`
pela mesma senha do `.env`:

```bash
dotnet user-secrets set "ConnectionStrings:Default" "Host=localhost;Port=5432;Database=mercadinho;Username=mercadinho;Password=SUA_SENHA" --project src/Mercadinho.Api
```

Depois, rode a API e o desktop:

```bash
dotnet run --project src/Mercadinho.Api
dotnet run --project src/Mercadinho.Desktop
```

### Testes

```bash
dotnet test
```

Os testes não precisam de senha nem de banco: a API de teste usa uma conexão
falsa (`tests/Mercadinho.Api.Tests/ApiFactory.cs`).

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
