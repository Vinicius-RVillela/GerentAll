# Plano do MVP — Controle de Produtos para Mercadinho

Objetivo: um sistema de retaguarda (estoque) para mercadinho, rodando em
Linux e Windows 10/11, pensado como **projeto de portfólio** bem acabado.
Emissão fiscal (devolução, NFS-e) fica fora do MVP de propósito.

---

## 1. Stack

| Camada | Tecnologia | Motivo |
|---|---|---|
| Back-end | ASP.NET Core Web API (.NET 10 LTS) | C#, padrão de mercado em vagas |
| ORM | Entity Framework Core + migrations | Versiona o banco junto com o código |
| Banco | PostgreSQL (SQLite opcional p/ modo demo) | Gratuito, robusto, roda em Docker |
| Front-end | Avalonia UI 12 + MVVM (CommunityToolkit.Mvvm) | Desktop nativo Linux + Windows em C# |
| Autenticação | JWT + perfis (Admin, Gerente, Operador) | Controle de acesso por tela/ação |
| Testes | xUnit + FluentAssertions + Testcontainers | Testes de regra e de integração com banco real |
| Docs da API | Swagger / OpenAPI | Recrutador consegue "ver" a API |
| Infra | Docker Compose (api + postgres) | Sobe tudo com um comando |
| CI | GitHub Actions (build + testes a cada push) | Mostra disciplina de engenharia |

## 2. Estrutura da solução

```
src/
  Mercadinho.Domain/          entidades e regras (sem dependência de banco/UI)
  Mercadinho.Application/     casos de uso (ex.: RegistrarAvaria, ImportarNFe)
  Mercadinho.Infrastructure/  EF Core, Postgres, leitor de XML
  Mercadinho.Api/             controllers, auth, Swagger
  Mercadinho.Desktop/         Avalonia (Views + ViewModels)
tests/
  Mercadinho.Domain.Tests/
  Mercadinho.Api.Tests/       integração com Testcontainers
docker-compose.yml
```

## 3. Modelo de dados (núcleo)

- **Produto**: id, nome, código de barras (EAN), unidade (UN, KG, CX),
  categoria, preço de custo, preço de venda, estoque mínimo, ativo.
- **Categoria**, **Fornecedor** (CNPJ, nome).
- **Lote**: produto, validade, quantidade — *mercadinho vive de validade*.
- **MovimentacaoEstoque**: produto, lote, tipo, quantidade, data, usuário,
  motivo, referência (id da nota, se houver).
  Tipos: `Entrada`, `Venda`, `Avaria`, `Devolucao`, `Ajuste`.
- **NotaEntrada** + **ItemNotaEntrada**: chave de acesso, fornecedor,
  data de emissão, status (`Importada`, `EmTransito`, `Recebida`), itens.
- **Usuario** (perfil, senha com hash).

**Decisão de design importante:** o saldo do estoque **não é um número
editável**. Ele é a soma das movimentações (livro-razão). Toda alteração
deixa rastro: quem, quando e por quê. Isso evita estoque "sumindo" e é um
ótimo assunto para entrevista.

## 4. Fases (estimativa para ~10 h/semana)

### Fase 0 — Fundação (1 semana)
- Repositório no GitHub, solução .NET, Docker Compose com Postgres.
- CI rodando build e testes.
- README inicial com objetivo e como rodar.

### Fase 1 — Cadastros (2 semanas)
- CRUD de produto, categoria e fornecedor (API + telas Avalonia).
- Busca por nome e código de barras; validações (EAN válido, preço > 0).
- Testes das regras de domínio.

### Fase 2 — Estoque (2–3 semanas)
- Movimentações: entrada manual, venda (lançamento simples), avaria,
  devolução (exige referência a uma nota), ajuste (só Gerente/Admin).
- Saldo por produto e por lote; alerta de estoque mínimo e de validade
  próxima (ex.: 7 dias).
- Testes: não permitir saldo negativo, avaria registra motivo, etc.

### Fase 3 — Importação de NF-e por XML (2 semanas)
- Usuário seleciona o arquivo XML baixado do fornecedor/portal.
- Ler com `XDocument` (namespace `http://www.portalfiscal.inf.br/nfe`):
  emitente, chave, itens (`det/prod`: cProd, xProd, cEAN, qCom, vUnCom).
- Tela de **vincular itens da nota aos produtos** cadastrados (pelo EAN;
  se não achar, sugere cadastrar).
- Nota fica `EmTransito` → aba **"A chegar"** lista o que ainda não foi
  conferido → botão **"Conferir recebimento"** gera as entradas no estoque.
- Bloquear importação duplicada pela chave de acesso.
- Testes com XMLs de exemplo (sem dados reais de empresas).

### Fase 4 — Relatórios e projeção (2 semanas)
- Vendas por produto nos últimos N meses (tabela + gráfico).
- Curva ABC (quais produtos mais vendem).
- Projeção do próximo mês: média móvel ponderada dos últimos 3 meses;
  depois, se quiser, ML.NET (SSA) e comparar os dois.
- Exportar relatório em CSV/PDF.

### Fase 5 — Usuários e configuração (1–2 semanas)
- Login, perfis, troca de senha; cada movimentação registra o usuário.
- Tela de configuração: dados da loja, dias de alerta de validade.
- Tela "Banco de dados" **segura**: backup, restauração e verificação —
  sem SQL livre.

### Fase 6 — Polimento para portfólio (1 semana)
- README com prints, GIF de uso, diagrama da arquitetura e decisões.
- Dados de demonstração (seed) para testar em 1 minuto.
- Release com executáveis para Windows e Linux (GitHub Releases).
- Vídeo curto (2–3 min) mostrando o fluxo: importar nota → conferir →
  vender → relatório.

**Total estimado: 11–14 semanas.** Termine cada fase antes de começar a
próxima: um projeto pequeno e terminado vale mais que um grande pela metade.

## 5. Fora do MVP (futuro)

- Download automático de NF-e pela SEFAZ (Distribuição DF-e + manifestação,
  exige certificado A1).
- CT-e (frete) e NFS-e (serviço).
- Emissão de nota de devolução (via biblioteca fiscal ou API paga).
- PDV / NFC-e e integração com balança.
- Multi-loja.

## 6. Checklist de qualidade (o que recrutador olha)

- [ ] Commits pequenos com mensagens claras
- [ ] Testes rodando no CI (badge verde no README)
- [ ] Sobe com `docker compose up` sem passos escondidos
- [ ] Nenhuma senha/chave no repositório (`.env.example`)
- [ ] README explica **por que** das decisões, não só o **como**
- [ ] Issues/Project do GitHub mostrando o planejamento
