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
                              Infrastructure (EF Core) ──▶ MariaDB
```

| Camada | Tecnologia |
|---|---|
| API | ASP.NET Core (.NET 10), OpenAPI/Swagger |
| Banco | MariaDB 11.4 LTS + Entity Framework Core (MySql.EntityFrameworkCore) |
| Desktop | Avalonia UI 12 + MVVM (CommunityToolkit.Mvvm) |
| Testes | xUnit, WebApplicationFactory |
| Infra | Docker Compose, GitHub Actions |

## Como rodar

### Com Docker (API + banco)

```bash
cp .env.example .env      # ajuste a senha
docker compose up --build
```

Na primeira vez, o MariaDB cria o banco `gerentall` sozinho, rodando
`database/mariadb/01_estrutura.sql`. Ele só aceita conexões deste computador,
na porta `127.0.0.1:3307` (a 3307 evita conflito com um MariaDB já instalado).

- Saúde da API: http://localhost:8080/health/live
- Conexão com o banco: http://localhost:8080/health/ready
- Swagger: http://localhost:8080/swagger

### Sem Docker (desenvolvimento)

Requer .NET SDK 10 e um MariaDB 10.11+ (ou o do Docker: `docker compose up -d db`).

**1. Crie o banco** com os scripts de [`database/mariadb`](database/mariadb/README.md):

```bash
mysql -h 127.0.0.1 -u root -p < database/mariadb/01_estrutura.sql
mysql -h 127.0.0.1 -u root -p < database/mariadb/02_dados_exemplo.sql   # opcional
```

**2. Crie um usuário só para a API**, que lê e grava dados mas não pode apagar
tabelas nem mexer em outros bancos. Rode no DBeaver (como root), trocando `SUA_SENHA`:

```sql
CREATE USER 'gerentall_app'@'localhost' IDENTIFIED BY 'SUA_SENHA';
GRANT SELECT, INSERT, UPDATE, DELETE, EXECUTE ON gerentall.* TO 'gerentall_app'@'localhost';
```

**3. Guarde a conexão no user-secrets.** Ela **não fica no repositório**: o
[user-secrets](https://learn.microsoft.com/aspnet/core/security/app-secrets)
do .NET guarda fora da pasta do projeto. Use a mesma senha do passo 2
(com o MariaDB do Docker, use `Port=3307` e a senha do `.env`):

```bash
dotnet user-secrets set "ConnectionStrings:Default" "Server=localhost;Port=3306;Database=gerentall;Uid=gerentall_app;Pwd=SUA_SENHA" --project src/Mercadinho.Api
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
  Mercadinho.Infrastructure/  banco de dados (EF Core + MariaDB)
  Mercadinho.Api/             API REST
  Mercadinho.Desktop/         aplicativo desktop (Avalonia)
tests/
  Mercadinho.Domain.Tests/
  Mercadinho.Api.Tests/
database/
  mariadb/                    scripts SQL: estrutura e dados de exemplo
docs/
  PLANO_MVP.md
```
