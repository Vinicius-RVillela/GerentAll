# Banco de dados do GerentAll (MariaDB / MySQL)

| Arquivo | O que faz |
|---|---|
| `01_estrutura.sql` | Apaga e cria o banco `gerentall`: 19 tabelas, regras (CHECK e UNIQUE), triggers, funções e 10 views |
| `02_dados_exemplo.sql` | Opcional. Dados fictícios: 6 produtos, 1 nota recebida, vendas nos 3 últimos meses, avaria, ajuste e troca de preço |

## Como rodar

```bash
cd ~/projetos/My_Gerent_App
mysql -h 127.0.0.1 -u root -p < database/mariadb/01_estrutura.sql
mysql -h 127.0.0.1 -u root -p < database/mariadb/02_dados_exemplo.sql
```

No DBeaver: abra o arquivo e use **Executar script (Alt+X)**, não Ctrl+Enter.

> O `01_estrutura.sql` começa com `DROP DATABASE IF EXISTS gerentall`.
> Ele **apaga tudo**. Use só para criar do zero.

## As tabelas

| Grupo | Tabelas |
|---|---|
| Configuração | `loja_config`, `perfil`, `unidade` |
| Acesso | `usuario`, `log_acesso` |
| Cadastros | `categoria`, `fornecedor`, `produto`, `lote`, `historico_produto` |
| Notas (NF-e) | `nota_entrada`, `nota_entrada_item` |
| PDV | `caixa`, `sessao_caixa`, `venda`, `venda_item`, `pagamento` |
| Estoque | `movimentacao_estoque` (livro-razão) |
| Cálculos | `projecao_venda` |

## Onde está o "estoque"

Não existe uma coluna "quantidade em estoque" para alguém editar. O saldo é
**calculado** somando `movimentacao_estoque`. Para ver o estoque, use as views:

```sql
SELECT * FROM vw_estoque_produto;      -- saldo por produto
SELECT * FROM vw_estoque_lote;         -- saldo por lote, com dias para vencer
SELECT * FROM vw_alerta_validade;      -- lotes vencendo
SELECT * FROM vw_alerta_estoque_minimo;
```

Relatórios: `vw_produto_margem`, `vw_vendas_mensais`, `vw_curva_abc`,
`vw_projecao_mes_atual`, `vw_fechamento_caixa`, `vw_conferencia_venda`.

## Quem alterou o produto (`@usuario_id`)

A trigger `tg_produto_historico` grava em `historico_produto` quem fez a
alteração, lendo a variável `@usuario_id` da conexão. A aplicação precisa rodar
`SET @usuario_id = '<id do usuário logado>'` **no começo de cada transação**.

Cuidado com o *pool de conexões*: a aplicação reaproveita conexões entre
usuários, então uma variável esquecida de um usuário pode "vazar" para o
próximo. Por isso a regra é definir a variável sempre, no início de cada transação.
