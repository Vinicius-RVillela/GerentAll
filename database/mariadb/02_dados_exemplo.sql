-- =====================================================================
-- GerentAll — Arquivo 2 de 2: DADOS DE EXEMPLO (opcional)
-- Rode DEPOIS do 01_estrutura.sql:
--   mysql -h 127.0.0.1 -u root -p < database/mariadb/02_dados_exemplo.sql
--
-- Tudo aqui é fictício: CNPJs, chave da nota e pessoas. As datas são
-- relativas a HOJE (vendas nos 3 meses anteriores), então as views de
-- relatório e projeção sempre mostram alguma coisa.
-- Os usuários de exemplo ficam DESATIVADOS e sem senha de verdade:
-- ninguém consegue entrar com eles.
-- =====================================================================

USE gerentall;

INSERT INTO loja_config (id, nome_loja, cnpj, telefone, dias_alerta_validade, dias_relatorio_abc)
VALUES (1, 'Mercadinho Exemplo', NULL, '(31) 0000-0000', 7, 90);

-- ---------------------------------------------------------------------
-- Usuários (desativados; o hash é um texto qualquer, não uma senha)
-- ---------------------------------------------------------------------
SET @u_admin    = UUID();
SET @u_gerente  = UUID();
SET @u_operador = UUID();

INSERT INTO usuario (id, nome, email, senha_hash, perfil_id, ativo) VALUES
    (@u_admin,    'Admin (exemplo)',    'admin@exemplo.local',    'SEM_SENHA_crie_pelo_sistema', 1, FALSE),
    (@u_gerente,  'Gerente (exemplo)',  'gerente@exemplo.local',  'SEM_SENHA_crie_pelo_sistema', 2, FALSE),
    (@u_operador, 'Operador (exemplo)', 'operador@exemplo.local', 'SEM_SENHA_crie_pelo_sistema', 3, FALSE);

-- A partir daqui, o histórico de produto registra o gerente como autor.
SET @usuario_id = @u_gerente;

-- ---------------------------------------------------------------------
-- Datas de referência
-- ---------------------------------------------------------------------
SET @mes_atual = CAST(DATE_FORMAT(UTC_DATE(), '%Y-%m-01') AS DATETIME(3));
SET @mes_1 = @mes_atual - INTERVAL 1 MONTH;   -- mês passado
SET @mes_2 = @mes_atual - INTERVAL 2 MONTH;
SET @mes_3 = @mes_atual - INTERVAL 3 MONTH;

-- ---------------------------------------------------------------------
-- Cadastros
-- ---------------------------------------------------------------------
SET @c_mercearia = UUID(); SET @c_laticinios = UUID(); SET @c_bebidas = UUID(); SET @c_frios = UUID();
INSERT INTO categoria (id, nome) VALUES
    (@c_mercearia, 'Mercearia'), (@c_laticinios, 'Laticínios'),
    (@c_bebidas, 'Bebidas'), (@c_frios, 'Frios');

SET @f_distribuidora = UUID();
INSERT INTO fornecedor (id, cnpj, razao_social, nome_fantasia, telefone) VALUES
    (@f_distribuidora, '99999999000199', 'Distribuidora Exemplo LTDA', 'Distribuidora Exemplo', '(31) 0000-0001');

SET @p_arroz = UUID(); SET @p_feijao = UUID(); SET @p_leite = UUID();
SET @p_refri = UUID(); SET @p_queijo = UUID(); SET @p_cafe = UUID();

INSERT INTO produto (id, nome, codigo_barras, unidade_id, categoria_id, preco_custo, preco_venda, estoque_minimo) VALUES
    (@p_arroz,  'Arroz tipo 1 5kg',        '7891000100103', 1, @c_mercearia,  20.00, 27.90, 10),
    (@p_feijao, 'Feijão carioca 1kg',      '7890000001014', 1, @c_mercearia,   6.50,  9.49, 15),
    (@p_leite,  'Leite integral 1L',       '7890000002028', 1, @c_laticinios,  4.10,  5.99, 24),
    (@p_refri,  'Refrigerante cola 2L',    '7890000003032', 1, @c_bebidas,     6.00,  9.99, 12),
    (@p_queijo, 'Queijo muçarela (peso)',  NULL,            2, @c_frios,      32.00, 49.90,  3),
    (@p_cafe,   'Café torrado 500g',       '7890000004046', 1, @c_mercearia,  14.00, 21.90, 25);

-- Lotes com validade (leite e queijo). Um lote de leite vence em 4 dias:
-- ele aparece na view vw_alerta_validade.
SET @l_leite_perto = UUID(); SET @l_leite_longe = UUID(); SET @l_queijo = UUID();
INSERT INTO lote (id, produto_id, codigo, validade) VALUES
    (@l_leite_perto, @p_leite,  'L2401', UTC_DATE() + INTERVAL 4 DAY),
    (@l_leite_longe, @p_leite,  'L2455', UTC_DATE() + INTERVAL 60 DAY),
    (@l_queijo,      @p_queijo, 'Q0912', UTC_DATE() + INTERVAL 20 DAY);

-- ---------------------------------------------------------------------
-- Nota de entrada recebida (chave fictícia, 44 números)
-- cUF 35 + AAMM + CNPJ + modelo 55 + série + número + tpEmis + código + DV
-- ---------------------------------------------------------------------
SET @n_nota = UUID();
INSERT INTO nota_entrada (id, chave_acesso, fornecedor_id, numero, serie, data_emissao, valor_total,
                          status, importada_em, importada_por, recebida_em, recebida_por)
VALUES (@n_nota, '35260899999999000199550010000012341000012345', @f_distribuidora, 1234, 1,
        @mes_3 - INTERVAL 6 DAY, 3422.40,
        'RECEBIDA', @mes_3 - INTERVAL 6 DAY, @u_gerente, @mes_3 - INTERVAL 5 DAY, @u_gerente);

INSERT INTO nota_entrada_item (nota_entrada_id, numero_item, codigo_fornecedor, descricao, gtin,
                               quantidade, valor_unitario, produto_id, lote_codigo, validade) VALUES
    (@n_nota, 1, 'ARZ5',  'ARROZ T1 5KG',          '7891000100103', 60,   20.00, @p_arroz,  NULL,   NULL),
    (@n_nota, 2, 'FJC1',  'FEIJAO CARIOCA 1KG',    '7890000001014', 80,    6.50, @p_feijao, NULL,   NULL),
    (@n_nota, 3, 'LTI1',  'LEITE INTEGRAL 1L',     '7890000002028', 24,    4.10, @p_leite,  'L2401', UTC_DATE() + INTERVAL 4 DAY),
    (@n_nota, 4, 'LTI1B', 'LEITE INTEGRAL 1L',     '7890000002028', 80,    4.10, @p_leite,  'L2455', UTC_DATE() + INTERVAL 60 DAY),
    (@n_nota, 5, 'RFC2',  'REFRIG COLA 2L',        '7890000003032', 60,    6.00, @p_refri,  NULL,   NULL),
    (@n_nota, 6, 'QMZ',   'QUEIJO MUCARELA KG',    NULL,            15.5, 32.00, @p_queijo, 'Q0912', UTC_DATE() + INTERVAL 20 DAY),
    (@n_nota, 7, 'CAF5',  'CAFE TORRADO 500G',     '7890000004046', 30,   14.00, @p_cafe,   NULL,   NULL);

-- Conferir o recebimento = gerar as ENTRADAS no livro-razão.
SET @quando_entrada = @mes_3 - INTERVAL 5 DAY;
INSERT INTO movimentacao_estoque (produto_id, lote_id, tipo, quantidade, custo_unitario, nota_entrada_id, usuario_id, ocorrido_em) VALUES
    (@p_arroz,  NULL,           'ENTRADA', 60,   20.00, @n_nota, @u_gerente, @quando_entrada),
    (@p_feijao, NULL,           'ENTRADA', 80,    6.50, @n_nota, @u_gerente, @quando_entrada),
    (@p_leite,  @l_leite_perto, 'ENTRADA', 24,    4.10, @n_nota, @u_gerente, @quando_entrada),
    (@p_leite,  @l_leite_longe, 'ENTRADA', 80,    4.10, @n_nota, @u_gerente, @quando_entrada),
    (@p_refri,  NULL,           'ENTRADA', 60,    6.00, @n_nota, @u_gerente, @quando_entrada),
    (@p_queijo, @l_queijo,      'ENTRADA', 15.5, 32.00, @n_nota, @u_gerente, @quando_entrada),
    (@p_cafe,   NULL,           'ENTRADA', 30,   14.00, @n_nota, @u_gerente, @quando_entrada);

-- ---------------------------------------------------------------------
-- PDV: um procedimento TEMPORÁRIO que faz uma venda completa de 1 item
-- (venda + item + pagamento + saída no estoque). Ele é apagado no fim.
-- ---------------------------------------------------------------------
INSERT INTO caixa (nome) VALUES ('Caixa 1');
SET @caixa = LAST_INSERT_ID();

DELIMITER $$
CREATE PROCEDURE tmp_vender(
    IN p_sessao UUID, IN p_produto UUID, IN p_lote UUID,
    IN p_qtd DECIMAL(12,3), IN p_forma VARCHAR(10), IN p_quando DATETIME(3))
BEGIN
    DECLARE v_venda UUID DEFAULT UUID();
    DECLARE v_preco DECIMAL(12,2);
    DECLARE v_total DECIMAL(12,2);
    DECLARE v_entregue DECIMAL(12,2);

    SELECT preco_venda INTO v_preco FROM produto WHERE id = p_produto;
    SET v_total = ROUND(p_qtd * v_preco, 2);

    INSERT INTO venda (id, sessao_caixa_id, usuario_id, status, subtotal, iniciada_em, finalizada_em)
    VALUES (v_venda, p_sessao, @u_operador, 'FINALIZADA', v_total, p_quando, p_quando);

    INSERT INTO venda_item (venda_id, produto_id, lote_id, quantidade, preco_unitario)
    VALUES (v_venda, p_produto, p_lote, p_qtd, v_preco);

    IF p_forma = 'DINHEIRO' THEN
        SET v_entregue = CEILING(v_total / 10) * 10;          -- cliente paga com nota "redonda"
        INSERT INTO pagamento (venda_id, forma, valor, troco, recebido_em)
        VALUES (v_venda, 'DINHEIRO', v_entregue, v_entregue - v_total, p_quando);
    ELSE
        INSERT INTO pagamento (venda_id, forma, valor, recebido_em)
        VALUES (v_venda, p_forma, v_total, p_quando);
    END IF;

    INSERT INTO movimentacao_estoque (produto_id, lote_id, tipo, quantidade, venda_id, usuario_id, ocorrido_em)
    VALUES (p_produto, p_lote, 'VENDA', -p_qtd, v_venda, @u_operador, p_quando);
END$$
DELIMITER ;

-- Um turno de caixa por mês, com as vendas do mês e o fechamento.
-- Mês -3
SET @s = UUID();
INSERT INTO sessao_caixa (id, caixa_id, aberta_por, aberta_em, valor_abertura)
VALUES (@s, @caixa, @u_operador, @mes_3 + INTERVAL 8 HOUR, 100.00);
CALL tmp_vender(@s, @p_arroz,  NULL,           8,     'PIX',      @mes_3 + INTERVAL 3 DAY  + INTERVAL 10 HOUR);
CALL tmp_vender(@s, @p_feijao, NULL,           12,    'DINHEIRO', @mes_3 + INTERVAL 5 DAY  + INTERVAL 11 HOUR);
CALL tmp_vender(@s, @p_leite,  @l_leite_longe, 20,    'DEBITO',   @mes_3 + INTERVAL 9 DAY  + INTERVAL 9 HOUR);
CALL tmp_vender(@s, @p_refri,  NULL,           10,    'CREDITO',  @mes_3 + INTERVAL 12 DAY + INTERVAL 18 HOUR);
CALL tmp_vender(@s, @p_queijo, @l_queijo,      3.250, 'DINHEIRO', @mes_3 + INTERVAL 15 DAY + INTERVAL 16 HOUR);
CALL tmp_vender(@s, @p_cafe,   NULL,           3,     'PIX',      @mes_3 + INTERVAL 20 DAY + INTERVAL 10 HOUR);
UPDATE sessao_caixa
SET fechada_por = @u_operador, fechada_em = @mes_3 + INTERVAL 27 DAY + INTERVAL 20 HOUR,
    valor_fechamento_informado = (SELECT dinheiro_esperado FROM vw_fechamento_caixa WHERE sessao_caixa_id = @s)
WHERE id = @s;

-- Mês -2
SET @s = UUID();
INSERT INTO sessao_caixa (id, caixa_id, aberta_por, aberta_em, valor_abertura)
VALUES (@s, @caixa, @u_operador, @mes_2 + INTERVAL 8 HOUR, 100.00);
CALL tmp_vender(@s, @p_arroz,  NULL,           10,    'DINHEIRO', @mes_2 + INTERVAL 2 DAY  + INTERVAL 10 HOUR);
CALL tmp_vender(@s, @p_feijao, NULL,           14,    'PIX',      @mes_2 + INTERVAL 6 DAY  + INTERVAL 11 HOUR);
CALL tmp_vender(@s, @p_leite,  @l_leite_longe, 22,    'PIX',      @mes_2 + INTERVAL 8 DAY  + INTERVAL 9 HOUR);
CALL tmp_vender(@s, @p_refri,  NULL,           9,     'DINHEIRO', @mes_2 + INTERVAL 13 DAY + INTERVAL 18 HOUR);
CALL tmp_vender(@s, @p_queijo, @l_queijo,      4.100, 'DEBITO',   @mes_2 + INTERVAL 16 DAY + INTERVAL 16 HOUR);
CALL tmp_vender(@s, @p_cafe,   NULL,           4,     'CREDITO',  @mes_2 + INTERVAL 21 DAY + INTERVAL 10 HOUR);
-- Neste mês o operador contou R$ 2,00 a menos na gaveta: a view mostra a diferença.
UPDATE sessao_caixa
SET fechada_por = @u_operador, fechada_em = @mes_2 + INTERVAL 27 DAY + INTERVAL 20 HOUR,
    valor_fechamento_informado = (SELECT dinheiro_esperado - 2.00 FROM vw_fechamento_caixa WHERE sessao_caixa_id = @s)
WHERE id = @s;

-- Mês -1 (mês passado)
SET @s = UUID();
INSERT INTO sessao_caixa (id, caixa_id, aberta_por, aberta_em, valor_abertura)
VALUES (@s, @caixa, @u_operador, @mes_1 + INTERVAL 8 HOUR, 100.00);
CALL tmp_vender(@s, @p_arroz,  NULL,           12,    'PIX',      @mes_1 + INTERVAL 4 DAY  + INTERVAL 10 HOUR);
CALL tmp_vender(@s, @p_feijao, NULL,           15,    'DINHEIRO', @mes_1 + INTERVAL 7 DAY  + INTERVAL 11 HOUR);
CALL tmp_vender(@s, @p_leite,  @l_leite_longe, 24,    'DEBITO',   @mes_1 + INTERVAL 10 DAY + INTERVAL 9 HOUR);
CALL tmp_vender(@s, @p_refri,  NULL,           12,    'PIX',      @mes_1 + INTERVAL 14 DAY + INTERVAL 18 HOUR);
CALL tmp_vender(@s, @p_queijo, @l_queijo,      3.800, 'DINHEIRO', @mes_1 + INTERVAL 17 DAY + INTERVAL 16 HOUR);
CALL tmp_vender(@s, @p_cafe,   NULL,           2,     'PIX',      @mes_1 + INTERVAL 22 DAY + INTERVAL 10 HOUR);
UPDATE sessao_caixa
SET fechada_por = @u_operador, fechada_em = @mes_1 + INTERVAL 27 DAY + INTERVAL 20 HOUR,
    valor_fechamento_informado = (SELECT dinheiro_esperado FROM vw_fechamento_caixa WHERE sessao_caixa_id = @s)
WHERE id = @s;

-- Turno de hoje, ainda aberto (só pode existir UM aberto por caixa).
SET @s_hoje = UUID();
INSERT INTO sessao_caixa (id, caixa_id, aberta_por, valor_abertura)
VALUES (@s_hoje, @caixa, @u_operador, 150.00);

-- Uma venda cancelada (sem itens): mostra a regra de cancelamento.
INSERT INTO venda (sessao_caixa_id, usuario_id, status, cancelada_em, cancelada_por, motivo_cancelamento)
VALUES (@s_hoje, @u_operador, 'CANCELADA', UTC_TIMESTAMP(3), @u_gerente, 'Cliente desistiu da compra');

DROP PROCEDURE tmp_vender;

-- ---------------------------------------------------------------------
-- Outras movimentações
-- ---------------------------------------------------------------------
-- Avaria: 2 leites do lote que está vencendo chegaram amassados.
INSERT INTO movimentacao_estoque (produto_id, lote_id, tipo, quantidade, motivo, usuario_id)
VALUES (@p_leite, @l_leite_perto, 'AVARIA', -2, 'Caixa amassada na prateleira', @u_operador);

-- Ajuste de inventário (só Gerente/Admin): faltou 1 pacote de arroz na contagem.
INSERT INTO movimentacao_estoque (produto_id, tipo, quantidade, motivo, usuario_id)
VALUES (@p_arroz, 'AJUSTE', -1, 'Inventário: contagem física com 1 pacote a menos', @u_gerente);

-- Reajuste de preço: vira uma linha em historico_produto (pela trigger).
UPDATE produto SET preco_custo = 21.00, preco_venda = 28.90 WHERE id = @p_arroz;

-- ---------------------------------------------------------------------
-- Log de acesso e projeção salva
-- ---------------------------------------------------------------------
INSERT INTO log_acesso (email_informado, usuario_id, sucesso, ip) VALUES
    ('gerente@exemplo.local', @u_gerente, TRUE,  '192.168.0.10'),
    ('gerente@exemplo.local', @u_gerente, FALSE, '192.168.0.10'),
    ('quem@naoexiste.com',    NULL,       FALSE, '192.168.0.55');

CALL sp_salvar_projecao();

SET @usuario_id = NULL;
