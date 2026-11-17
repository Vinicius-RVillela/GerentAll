-- =====================================================================
-- GerentAll — banco de dados (MariaDB 10.11+ / MySQL 8 com ajustes)
-- Arquivo 1 de 2: ESTRUTURA (tabelas, regras, triggers, funções e views)
--
-- Como rodar (terminal do Linux Mint):
--   mysql -h 127.0.0.1 -u root -p < database/mariadb/01_estrutura.sql
-- No DBeaver: abra o arquivo e use "Executar script" (Alt+X).
--
-- ATENÇÃO: a primeira linha APAGA o banco gerentall inteiro e cria de novo.
-- Rode só para criar do zero, nunca num banco com dados reais.
--
-- Ideias principais do modelo:
--   1. O ESTOQUE não é um número editável. O saldo é a SOMA das
--      movimentações (livro-razão). Toda mudança deixa rastro: quem, quando, por quê.
--   2. Movimentações nunca são alteradas nem apagadas: errou, lança um AJUSTE.
--   3. Datas e horas em UTC. A tela converte para o horário de Brasília.
--   4. Os ids das entidades são UUID (o C# usa Guid). Tabelas de "linhas"
--      (itens, logs, movimentações) usam número sequencial (BIGINT).
-- =====================================================================

DROP DATABASE IF EXISTS gerentall;
CREATE DATABASE gerentall CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE gerentall;

-- =====================================================================
-- 1. CONFIGURAÇÃO E TABELAS DE APOIO
-- =====================================================================

-- Uma linha só (id = 1): dados da loja e parâmetros dos alertas e relatórios.
CREATE TABLE loja_config (
    id                    TINYINT UNSIGNED NOT NULL DEFAULT 1,
    nome_loja             VARCHAR(120)     NOT NULL,
    cnpj                  CHAR(14)         NULL,
    telefone              VARCHAR(20)      NULL,
    endereco              VARCHAR(200)     NULL,
    dias_alerta_validade  SMALLINT UNSIGNED NOT NULL DEFAULT 7,
    dias_relatorio_abc    SMALLINT UNSIGNED NOT NULL DEFAULT 90,
    PRIMARY KEY (id),
    CONSTRAINT ck_loja_config_linha_unica CHECK (id = 1),
    CONSTRAINT ck_loja_config_cnpj CHECK (cnpj IS NULL OR cnpj REGEXP '^[0-9]{14}$')
) ENGINE=InnoDB COMMENT='Dados da loja e parâmetros (uma linha só)';

-- Os números são os mesmos do enum Perfil do C# (Admin=1, Gerente=2, Operador=3).
CREATE TABLE perfil (
    id         TINYINT UNSIGNED NOT NULL,
    nome       VARCHAR(20)      NOT NULL,
    descricao  VARCHAR(200)     NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uq_perfil_nome (nome)
) ENGINE=InnoDB;

INSERT INTO perfil (id, nome, descricao) VALUES
    (1, 'Admin',    'Usuários, perfis, backup e configurações da loja'),
    (2, 'Gerente',  'Tudo do Operador + ajuste de estoque, notas e relatórios'),
    (3, 'Operador', 'Consulta produtos, registra vendas e avarias');

-- Os números são os mesmos do enum Unidade do C# (UN=1, KG=2, CX=3).
CREATE TABLE unidade (
    id             TINYINT UNSIGNED NOT NULL,
    sigla          VARCHAR(5)       NOT NULL,
    descricao      VARCHAR(50)      NOT NULL,
    aceita_fracao  BOOLEAN          NOT NULL COMMENT '1 = pode vender 0,350 (ex.: KG)',
    PRIMARY KEY (id),
    UNIQUE KEY uq_unidade_sigla (sigla)
) ENGINE=InnoDB;

INSERT INTO unidade (id, sigla, descricao, aceita_fracao) VALUES
    (1, 'UN', 'Unidade',    FALSE),
    (2, 'KG', 'Quilograma', TRUE),
    (3, 'CX', 'Caixa',      FALSE);

-- =====================================================================
-- 2. USUÁRIOS E ACESSO
-- =====================================================================

CREATE TABLE usuario (
    id                 UUID             NOT NULL DEFAULT UUID(),
    nome               VARCHAR(120)     NOT NULL,
    email              VARCHAR(254)     NOT NULL COMMENT 'Sempre minúsculo e sem espaços',
    senha_hash         VARCHAR(500)     NOT NULL COMMENT 'NUNCA a senha: só o hash',
    perfil_id          TINYINT UNSIGNED NOT NULL,
    ativo              BOOLEAN          NOT NULL DEFAULT TRUE,
    criado_em          DATETIME(3)      NOT NULL DEFAULT (UTC_TIMESTAMP(3)),
    ultimo_acesso_em   DATETIME(3)      NULL,
    tentativas_falhas  TINYINT UNSIGNED NOT NULL DEFAULT 0,
    bloqueado_ate      DATETIME(3)      NULL,
    carimbo_seguranca  UUID             NOT NULL DEFAULT UUID()
                       COMMENT 'Muda ao trocar senha/perfil/ativo: derruba logins abertos',
    PRIMARY KEY (id),
    UNIQUE KEY uq_usuario_email (email),
    CONSTRAINT fk_usuario_perfil FOREIGN KEY (perfil_id) REFERENCES perfil (id),
    CONSTRAINT ck_usuario_nome CHECK (CHAR_LENGTH(TRIM(nome)) > 0),
    -- CAST AS BINARY: sem ele, a comparação ignora maiúsculas (collation _ci)
    -- e 'Ana@x.com' = 'ana@x.com' daria verdadeiro.
    CONSTRAINT ck_usuario_email_normalizado
        CHECK (CAST(email AS BINARY) = CAST(LOWER(TRIM(email)) AS BINARY)),
    CONSTRAINT ck_usuario_email_formato
        CHECK (email REGEXP '^[^@[:space:]]+@[^@[:space:]]+\\.[^@[:space:]]+$'),
    CONSTRAINT ck_usuario_hash CHECK (CHAR_LENGTH(senha_hash) > 0)
) ENGINE=InnoDB;

-- Toda tentativa de login (certa ou errada). Serve para auditoria e para
-- perceber alguém "chutando" senhas.
CREATE TABLE log_acesso (
    id               BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    email_informado  VARCHAR(254)    NOT NULL,
    usuario_id       UUID            NULL COMMENT 'NULL quando o e-mail não existe',
    sucesso          BOOLEAN         NOT NULL,
    ip               VARCHAR(45)     NULL COMMENT '45 cabe um IPv6',
    ocorrido_em      DATETIME(3)     NOT NULL DEFAULT (UTC_TIMESTAMP(3)),
    PRIMARY KEY (id),
    KEY ix_log_acesso_email (email_informado, ocorrido_em),
    CONSTRAINT fk_log_acesso_usuario FOREIGN KEY (usuario_id)
        REFERENCES usuario (id) ON DELETE SET NULL
) ENGINE=InnoDB;

-- =====================================================================
-- 3. CADASTROS
-- =====================================================================

CREATE TABLE categoria (
    id     UUID         NOT NULL DEFAULT UUID(),
    nome   VARCHAR(80)  NOT NULL,
    ativo  BOOLEAN      NOT NULL DEFAULT TRUE,
    PRIMARY KEY (id),
    UNIQUE KEY uq_categoria_nome (nome)
) ENGINE=InnoDB;

CREATE TABLE fornecedor (
    id             UUID          NOT NULL DEFAULT UUID(),
    cnpj           CHAR(14)      NOT NULL COMMENT 'Só os 14 números, sem pontos',
    razao_social   VARCHAR(150)  NOT NULL,
    nome_fantasia  VARCHAR(150)  NULL,
    telefone       VARCHAR(20)   NULL,
    email          VARCHAR(254)  NULL,
    ativo          BOOLEAN       NOT NULL DEFAULT TRUE,
    criado_em      DATETIME(3)   NOT NULL DEFAULT (UTC_TIMESTAMP(3)),
    PRIMARY KEY (id),
    UNIQUE KEY uq_fornecedor_cnpj (cnpj),
    CONSTRAINT ck_fornecedor_cnpj CHECK (cnpj REGEXP '^[0-9]{14}$')
) ENGINE=InnoDB;

CREATE TABLE produto (
    id              UUID             NOT NULL DEFAULT UUID(),
    nome            VARCHAR(120)     NOT NULL,
    descricao       VARCHAR(500)     NULL,
    codigo_barras   CHAR(13)         NULL COMMENT 'EAN-13; NULL para produto sem código (ex.: pesado na hora)',
    unidade_id      TINYINT UNSIGNED NOT NULL,
    categoria_id    UUID             NULL,
    preco_custo     DECIMAL(12,2)    NOT NULL DEFAULT 0,
    preco_venda     DECIMAL(12,2)    NOT NULL,
    estoque_minimo  DECIMAL(12,3)    NOT NULL DEFAULT 0,
    ativo           BOOLEAN          NOT NULL DEFAULT TRUE,
    criado_em       DATETIME(3)      NOT NULL DEFAULT (UTC_TIMESTAMP(3)),
    atualizado_em   DATETIME(3)      NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uq_produto_codigo_barras (codigo_barras),   -- vários NULL são permitidos
    KEY ix_produto_nome (nome),
    KEY ix_produto_categoria (categoria_id),
    CONSTRAINT fk_produto_unidade   FOREIGN KEY (unidade_id)   REFERENCES unidade (id),
    CONSTRAINT fk_produto_categoria FOREIGN KEY (categoria_id) REFERENCES categoria (id),
    CONSTRAINT ck_produto_nome        CHECK (CHAR_LENGTH(TRIM(nome)) > 0),
    CONSTRAINT ck_produto_ean_formato CHECK (codigo_barras IS NULL OR codigo_barras REGEXP '^[0-9]{13}$'),
    CONSTRAINT ck_produto_custo       CHECK (preco_custo >= 0),
    CONSTRAINT ck_produto_venda       CHECK (preco_venda > 0),
    CONSTRAINT ck_produto_minimo      CHECK (estoque_minimo >= 0)
) ENGINE=InnoDB;

-- Lote = um grupo do mesmo produto com a mesma validade.
-- Mercadinho vive de validade: o leite que vence amanhã sai primeiro.
CREATE TABLE lote (
    id          UUID         NOT NULL DEFAULT UUID(),
    produto_id  UUID         NOT NULL,
    codigo      VARCHAR(40)  NULL COMMENT 'Lote do fabricante, se houver',
    validade    DATE         NULL COMMENT 'NULL = não perecível',
    criado_em   DATETIME(3)  NOT NULL DEFAULT (UTC_TIMESTAMP(3)),
    PRIMARY KEY (id),
    KEY ix_lote_produto_validade (produto_id, validade),
    CONSTRAINT fk_lote_produto FOREIGN KEY (produto_id) REFERENCES produto (id)
) ENGINE=InnoDB;

-- Toda mudança em produto (preço, nome, ativo...) vira uma linha aqui.
-- Quem preenche é a trigger tg_produto_historico (seção 7).
CREATE TABLE historico_produto (
    id            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    produto_id    UUID            NOT NULL,
    campo         VARCHAR(40)     NOT NULL,
    valor_antigo  VARCHAR(500)    NULL,
    valor_novo    VARCHAR(500)    NULL,
    usuario_id    UUID            NULL COMMENT 'Vem da variável @usuario_id da conexão',
    alterado_em   DATETIME(3)     NOT NULL DEFAULT (UTC_TIMESTAMP(3)),
    PRIMARY KEY (id),
    KEY ix_historico_produto (produto_id, alterado_em),
    CONSTRAINT fk_historico_produto FOREIGN KEY (produto_id) REFERENCES produto (id),
    CONSTRAINT fk_historico_usuario FOREIGN KEY (usuario_id) REFERENCES usuario (id)
) ENGINE=InnoDB;

-- =====================================================================
-- 4. NOTAS DE ENTRADA (NF-e importada por XML)
-- =====================================================================

CREATE TABLE nota_entrada (
    id             UUID           NOT NULL DEFAULT UUID(),
    chave_acesso   CHAR(44)       NOT NULL COMMENT 'Os 44 números da NF-e: impede importar duas vezes',
    fornecedor_id  UUID           NOT NULL,
    numero         INT UNSIGNED   NOT NULL,
    serie          SMALLINT UNSIGNED NOT NULL,
    data_emissao   DATETIME       NOT NULL,
    valor_total    DECIMAL(12,2)  NOT NULL,
    status         ENUM('IMPORTADA','EM_TRANSITO','RECEBIDA','CANCELADA') NOT NULL DEFAULT 'IMPORTADA',
    importada_em   DATETIME(3)    NOT NULL DEFAULT (UTC_TIMESTAMP(3)),
    importada_por  UUID           NOT NULL,
    recebida_em    DATETIME(3)    NULL,
    recebida_por   UUID           NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uq_nota_chave (chave_acesso),
    KEY ix_nota_status (status),
    CONSTRAINT fk_nota_fornecedor  FOREIGN KEY (fornecedor_id) REFERENCES fornecedor (id),
    CONSTRAINT fk_nota_importou    FOREIGN KEY (importada_por) REFERENCES usuario (id),
    CONSTRAINT fk_nota_recebeu     FOREIGN KEY (recebida_por)  REFERENCES usuario (id),
    CONSTRAINT ck_nota_chave       CHECK (chave_acesso REGEXP '^[0-9]{44}$'),
    CONSTRAINT ck_nota_valor       CHECK (valor_total >= 0),
    -- RECEBIDA <=> tem quem e quando recebeu
    CONSTRAINT ck_nota_recebimento CHECK ((status = 'RECEBIDA') = (recebida_em IS NOT NULL AND recebida_por IS NOT NULL))
) ENGINE=InnoDB;

CREATE TABLE nota_entrada_item (
    id                 BIGINT UNSIGNED  NOT NULL AUTO_INCREMENT,
    nota_entrada_id    UUID             NOT NULL,
    numero_item        SMALLINT UNSIGNED NOT NULL COMMENT 'nItem do XML',
    codigo_fornecedor  VARCHAR(60)      NOT NULL COMMENT 'cProd do XML',
    descricao          VARCHAR(200)     NOT NULL COMMENT 'xProd do XML',
    gtin               VARCHAR(14)      NULL COMMENT 'cEAN do XML; NULL quando vem "SEM GTIN"',
    quantidade         DECIMAL(12,3)    NOT NULL COMMENT 'qCom',
    valor_unitario     DECIMAL(14,4)    NOT NULL COMMENT 'vUnCom',
    produto_id         UUID             NULL COMMENT 'Vínculo com o produto da loja (NULL = ainda não vinculado)',
    lote_codigo        VARCHAR(40)      NULL,
    validade           DATE             NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uq_nota_item (nota_entrada_id, numero_item),
    CONSTRAINT fk_nota_item_nota    FOREIGN KEY (nota_entrada_id) REFERENCES nota_entrada (id) ON DELETE CASCADE,
    CONSTRAINT fk_nota_item_produto FOREIGN KEY (produto_id)      REFERENCES produto (id),
    CONSTRAINT ck_nota_item_qtd     CHECK (quantidade > 0),
    CONSTRAINT ck_nota_item_valor   CHECK (valor_unitario >= 0),
    CONSTRAINT ck_nota_item_gtin    CHECK (gtin IS NULL OR gtin REGEXP '^[0-9]{8,14}$')
) ENGINE=InnoDB;

-- =====================================================================
-- 5. PDV (frente de caixa) — sem emissão fiscal (NFC-e fica fora do MVP)
-- =====================================================================

CREATE TABLE caixa (
    id     TINYINT UNSIGNED NOT NULL AUTO_INCREMENT,
    nome   VARCHAR(40)      NOT NULL,
    ativo  BOOLEAN          NOT NULL DEFAULT TRUE,
    PRIMARY KEY (id),
    UNIQUE KEY uq_caixa_nome (nome)
) ENGINE=InnoDB;

-- Turno do caixa: abre com um troco inicial e fecha com a contagem do dinheiro.
CREATE TABLE sessao_caixa (
    id                          UUID             NOT NULL DEFAULT UUID(),
    caixa_id                    TINYINT UNSIGNED NOT NULL,
    aberta_por                  UUID             NOT NULL,
    aberta_em                   DATETIME(3)      NOT NULL DEFAULT (UTC_TIMESTAMP(3)),
    valor_abertura              DECIMAL(12,2)    NOT NULL DEFAULT 0,
    fechada_por                 UUID             NULL,
    fechada_em                  DATETIME(3)      NULL,
    valor_fechamento_informado  DECIMAL(12,2)    NULL COMMENT 'Dinheiro contado na gaveta',
    -- Coluna calculada: tem o número do caixa só enquanto a sessão está aberta.
    -- Com o UNIQUE abaixo, o banco impede DUAS sessões abertas no mesmo caixa.
    caixa_aberto                TINYINT UNSIGNED AS (IF(fechada_em IS NULL, caixa_id, NULL)) PERSISTENT,
    PRIMARY KEY (id),
    UNIQUE KEY uq_sessao_um_caixa_aberto (caixa_aberto),
    CONSTRAINT fk_sessao_caixa   FOREIGN KEY (caixa_id)    REFERENCES caixa (id),
    CONSTRAINT fk_sessao_abriu   FOREIGN KEY (aberta_por)  REFERENCES usuario (id),
    CONSTRAINT fk_sessao_fechou  FOREIGN KEY (fechada_por) REFERENCES usuario (id),
    CONSTRAINT ck_sessao_abertura CHECK (valor_abertura >= 0),
    CONSTRAINT ck_sessao_fechamento CHECK (
        (fechada_em IS NULL AND fechada_por IS NULL AND valor_fechamento_informado IS NULL)
        OR (fechada_em >= aberta_em AND fechada_por IS NOT NULL
            AND valor_fechamento_informado IS NOT NULL AND valor_fechamento_informado >= 0))
) ENGINE=InnoDB;

CREATE TABLE venda (
    id                   UUID            NOT NULL DEFAULT UUID(),
    numero               BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Número para as pessoas: Venda nº 1532',
    sessao_caixa_id      UUID            NOT NULL,
    usuario_id           UUID            NOT NULL COMMENT 'Operador que fez a venda',
    status               ENUM('ABERTA','FINALIZADA','CANCELADA') NOT NULL DEFAULT 'ABERTA',
    subtotal             DECIMAL(12,2)   NOT NULL DEFAULT 0 COMMENT 'Soma dos itens (gravada pela aplicação)',
    desconto             DECIMAL(12,2)   NOT NULL DEFAULT 0,
    total                DECIMAL(12,2)   AS (subtotal - desconto) PERSISTENT,
    iniciada_em          DATETIME(3)     NOT NULL DEFAULT (UTC_TIMESTAMP(3)),
    finalizada_em        DATETIME(3)     NULL,
    cancelada_em         DATETIME(3)     NULL,
    cancelada_por        UUID            NULL,
    motivo_cancelamento  VARCHAR(200)    NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uq_venda_numero (numero),
    KEY ix_venda_status_data (status, finalizada_em),
    CONSTRAINT fk_venda_sessao     FOREIGN KEY (sessao_caixa_id) REFERENCES sessao_caixa (id),
    CONSTRAINT fk_venda_usuario    FOREIGN KEY (usuario_id)      REFERENCES usuario (id),
    CONSTRAINT fk_venda_cancelou   FOREIGN KEY (cancelada_por)   REFERENCES usuario (id),
    CONSTRAINT ck_venda_valores    CHECK (subtotal >= 0 AND desconto >= 0 AND desconto <= subtotal),
    CONSTRAINT ck_venda_finalizada CHECK ((status = 'FINALIZADA') = (finalizada_em IS NOT NULL)),
    CONSTRAINT ck_venda_cancelada  CHECK ((status = 'CANCELADA') =
        (cancelada_em IS NOT NULL AND cancelada_por IS NOT NULL
         AND COALESCE(CHAR_LENGTH(TRIM(motivo_cancelamento)), 0) > 0))
) ENGINE=InnoDB;

CREATE TABLE venda_item (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    venda_id        UUID            NOT NULL,
    produto_id      UUID            NOT NULL,
    lote_id         UUID            NULL,
    quantidade      DECIMAL(12,3)   NOT NULL,
    preco_unitario  DECIMAL(12,2)   NOT NULL COMMENT 'Cópia do preço NA HORA da venda',
    desconto        DECIMAL(12,2)   NOT NULL DEFAULT 0,
    total           DECIMAL(12,2)   AS (ROUND(quantidade * preco_unitario - desconto, 2)) PERSISTENT,
    PRIMARY KEY (id),
    KEY ix_venda_item_venda (venda_id),
    KEY ix_venda_item_produto (produto_id),
    CONSTRAINT fk_venda_item_venda   FOREIGN KEY (venda_id)   REFERENCES venda (id) ON DELETE CASCADE,
    CONSTRAINT fk_venda_item_produto FOREIGN KEY (produto_id) REFERENCES produto (id),
    CONSTRAINT fk_venda_item_lote    FOREIGN KEY (lote_id)    REFERENCES lote (id),
    CONSTRAINT ck_venda_item_qtd     CHECK (quantidade > 0),
    CONSTRAINT ck_venda_item_preco   CHECK (preco_unitario > 0),
    CONSTRAINT ck_venda_item_desc    CHECK (desconto >= 0 AND desconto <= quantidade * preco_unitario)
) ENGINE=InnoDB;

CREATE TABLE pagamento (
    id           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    venda_id     UUID            NOT NULL,
    forma        ENUM('DINHEIRO','PIX','DEBITO','CREDITO','VALE') NOT NULL,
    valor        DECIMAL(12,2)   NOT NULL COMMENT 'Valor entregue pelo cliente',
    troco        DECIMAL(12,2)   NOT NULL DEFAULT 0,
    recebido_em  DATETIME(3)     NOT NULL DEFAULT (UTC_TIMESTAMP(3)),
    PRIMARY KEY (id),
    KEY ix_pagamento_venda (venda_id),
    CONSTRAINT fk_pagamento_venda FOREIGN KEY (venda_id) REFERENCES venda (id) ON DELETE CASCADE,
    CONSTRAINT ck_pagamento_valor CHECK (valor > 0),
    -- Só pagamento em dinheiro tem troco, e o troco nunca passa do valor entregue.
    CONSTRAINT ck_pagamento_troco CHECK (troco >= 0 AND troco < valor AND (troco = 0 OR forma = 'DINHEIRO'))
) ENGINE=InnoDB;

-- =====================================================================
-- 6. ESTOQUE: o livro-razão (cada linha é uma entrada ou saída)
-- =====================================================================
-- quantidade COM SINAL: positiva entra, negativa sai.
-- Saldo de um produto = SUM(quantidade) das linhas dele.

CREATE TABLE movimentacao_estoque (
    id               BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    produto_id       UUID            NOT NULL,
    lote_id          UUID            NULL,
    tipo             ENUM('ENTRADA','VENDA','AVARIA','DEVOLUCAO_FORNECEDOR','DEVOLUCAO_CLIENTE','AJUSTE') NOT NULL,
    quantidade       DECIMAL(12,3)   NOT NULL,
    custo_unitario   DECIMAL(14,4)   NULL COMMENT 'Custo na entrada (para valor do estoque)',
    motivo           VARCHAR(200)    NULL,
    nota_entrada_id  UUID            NULL,
    venda_id         UUID            NULL,
    usuario_id       UUID            NOT NULL,
    ocorrido_em      DATETIME(3)     NOT NULL DEFAULT (UTC_TIMESTAMP(3)),
    PRIMARY KEY (id),
    KEY ix_mov_produto_data (produto_id, ocorrido_em),
    KEY ix_mov_lote (lote_id),
    KEY ix_mov_tipo_data (tipo, ocorrido_em),
    CONSTRAINT fk_mov_produto FOREIGN KEY (produto_id)      REFERENCES produto (id),
    CONSTRAINT fk_mov_lote    FOREIGN KEY (lote_id)         REFERENCES lote (id),
    CONSTRAINT fk_mov_nota    FOREIGN KEY (nota_entrada_id) REFERENCES nota_entrada (id),
    CONSTRAINT fk_mov_venda   FOREIGN KEY (venda_id)        REFERENCES venda (id),
    CONSTRAINT fk_mov_usuario FOREIGN KEY (usuario_id)      REFERENCES usuario (id),
    CONSTRAINT ck_mov_nao_zero CHECK (quantidade <> 0),
    -- O sinal tem que combinar com o tipo.
    CONSTRAINT ck_mov_sinal CHECK (CASE tipo
        WHEN 'ENTRADA'              THEN quantidade > 0
        WHEN 'DEVOLUCAO_CLIENTE'    THEN quantidade > 0
        WHEN 'VENDA'                THEN quantidade < 0
        WHEN 'AVARIA'               THEN quantidade < 0
        WHEN 'DEVOLUCAO_FORNECEDOR' THEN quantidade < 0
        ELSE TRUE END),                                      -- AJUSTE: pode ser + ou -
    -- Cada tipo exige a sua referência ou o seu motivo.
    CONSTRAINT ck_mov_referencias CHECK (CASE tipo
        WHEN 'VENDA'                THEN venda_id IS NOT NULL
        WHEN 'DEVOLUCAO_CLIENTE'    THEN venda_id IS NOT NULL
        WHEN 'DEVOLUCAO_FORNECEDOR' THEN nota_entrada_id IS NOT NULL
        -- COALESCE: sem ele, motivo NULL daria NULL, e CHECK com NULL é ACEITO.
        WHEN 'AVARIA'               THEN COALESCE(CHAR_LENGTH(TRIM(motivo)), 0) > 0
        WHEN 'AJUSTE'               THEN COALESCE(CHAR_LENGTH(TRIM(motivo)), 0) > 0
        ELSE TRUE END)
) ENGINE=InnoDB COMMENT='Livro-razão do estoque: só INSERT, nunca UPDATE/DELETE';

-- =====================================================================
-- 7. CÁLCULOS: funções e projeções
-- =====================================================================

-- Projeções de venda salvas, para comparar métodos mês a mês
-- (média móvel ponderada agora; ML.NET depois, como no plano).
CREATE TABLE projecao_venda (
    id                   BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    produto_id           UUID            NOT NULL,
    mes_referencia       DATE            NOT NULL COMMENT 'Sempre o dia 1 do mês projetado',
    metodo               ENUM('MEDIA_MOVEL_PONDERADA','ML_SSA') NOT NULL,
    quantidade_prevista  DECIMAL(12,3)   NOT NULL,
    calculada_em         DATETIME(3)     NOT NULL DEFAULT (UTC_TIMESTAMP(3)),
    PRIMARY KEY (id),
    UNIQUE KEY uq_projecao (produto_id, mes_referencia, metodo),
    CONSTRAINT fk_projecao_produto FOREIGN KEY (produto_id) REFERENCES produto (id),
    CONSTRAINT ck_projecao_dia1 CHECK (DAY(mes_referencia) = 1),
    CONSTRAINT ck_projecao_qtd  CHECK (quantidade_prevista >= 0)
) ENGINE=InnoDB;

DELIMITER $$

-- Confere o dígito verificador do EAN-13 (a mesma conta do CodigoBarras.cs):
-- pesos 1 e 3 alternados; o dígito completa a soma até o próximo múltiplo de 10.
CREATE FUNCTION fn_ean13_valido(codigo VARCHAR(20)) RETURNS BOOLEAN
    DETERMINISTIC NO SQL
BEGIN
    DECLARE i INT DEFAULT 1;
    DECLARE soma INT DEFAULT 0;
    IF codigo IS NULL OR codigo NOT REGEXP '^[0-9]{13}$' THEN
        RETURN FALSE;
    END IF;
    WHILE i <= 12 DO
        SET soma = soma + CAST(SUBSTRING(codigo, i, 1) AS UNSIGNED) * IF(i % 2 = 1, 1, 3);
        SET i = i + 1;
    END WHILE;
    RETURN (10 - soma % 10) % 10 = CAST(SUBSTRING(codigo, 13, 1) AS UNSIGNED);
END$$

-- Saldo atual de um produto (soma do livro-razão).
CREATE FUNCTION fn_saldo_produto(p_produto UUID) RETURNS DECIMAL(14,3)
    READS SQL DATA
BEGIN
    RETURN (SELECT COALESCE(SUM(quantidade), 0)
            FROM movimentacao_estoque WHERE produto_id = p_produto);
END$$

-- =====================================================================
-- 8. TRIGGERS: regras que o banco garante mesmo se a aplicação esquecer
-- =====================================================================

-- Produto: EAN com dígito verificador certo (CHECK não pode chamar função).
CREATE TRIGGER tg_produto_valida_insert BEFORE INSERT ON produto
FOR EACH ROW
BEGIN
    IF NEW.codigo_barras IS NOT NULL AND NOT fn_ean13_valido(NEW.codigo_barras) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Código de barras EAN-13 inválido (dígito verificador).';
    END IF;
END$$

CREATE TRIGGER tg_produto_valida_update BEFORE UPDATE ON produto
FOR EACH ROW
BEGIN
    IF NEW.codigo_barras IS NOT NULL AND NOT fn_ean13_valido(NEW.codigo_barras) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Código de barras EAN-13 inválido (dígito verificador).';
    END IF;
    SET NEW.atualizado_em = UTC_TIMESTAMP(3);
END$$

-- Histórico: cada campo alterado vira uma linha em historico_produto.
-- "<=>" é a comparação que entende NULL (NULL <=> NULL é verdadeiro).
-- Quem alterou vem de @usuario_id: a aplicação roda SET @usuario_id = '...'
-- no começo de cada transação (veja o README desta pasta).
CREATE TRIGGER tg_produto_historico AFTER UPDATE ON produto
FOR EACH ROW
BEGIN
    IF NOT (OLD.nome <=> NEW.nome) THEN
        INSERT INTO historico_produto (produto_id, campo, valor_antigo, valor_novo, usuario_id)
        VALUES (NEW.id, 'nome', OLD.nome, NEW.nome, @usuario_id);
    END IF;
    IF NOT (OLD.preco_custo <=> NEW.preco_custo) THEN
        INSERT INTO historico_produto (produto_id, campo, valor_antigo, valor_novo, usuario_id)
        VALUES (NEW.id, 'preco_custo', OLD.preco_custo, NEW.preco_custo, @usuario_id);
    END IF;
    IF NOT (OLD.preco_venda <=> NEW.preco_venda) THEN
        INSERT INTO historico_produto (produto_id, campo, valor_antigo, valor_novo, usuario_id)
        VALUES (NEW.id, 'preco_venda', OLD.preco_venda, NEW.preco_venda, @usuario_id);
    END IF;
    IF NOT (OLD.codigo_barras <=> NEW.codigo_barras) THEN
        INSERT INTO historico_produto (produto_id, campo, valor_antigo, valor_novo, usuario_id)
        VALUES (NEW.id, 'codigo_barras', OLD.codigo_barras, NEW.codigo_barras, @usuario_id);
    END IF;
    IF NOT (OLD.estoque_minimo <=> NEW.estoque_minimo) THEN
        INSERT INTO historico_produto (produto_id, campo, valor_antigo, valor_novo, usuario_id)
        VALUES (NEW.id, 'estoque_minimo', OLD.estoque_minimo, NEW.estoque_minimo, @usuario_id);
    END IF;
    IF NOT (OLD.unidade_id <=> NEW.unidade_id) THEN
        INSERT INTO historico_produto (produto_id, campo, valor_antigo, valor_novo, usuario_id)
        VALUES (NEW.id, 'unidade_id', OLD.unidade_id, NEW.unidade_id, @usuario_id);
    END IF;
    IF NOT (OLD.categoria_id <=> NEW.categoria_id) THEN
        INSERT INTO historico_produto (produto_id, campo, valor_antigo, valor_novo, usuario_id)
        VALUES (NEW.id, 'categoria_id', OLD.categoria_id, NEW.categoria_id, @usuario_id);
    END IF;
    IF NOT (OLD.ativo <=> NEW.ativo) THEN
        INSERT INTO historico_produto (produto_id, campo, valor_antigo, valor_novo, usuario_id)
        VALUES (NEW.id, 'ativo', OLD.ativo, NEW.ativo, @usuario_id);
    END IF;
END$$

CREATE TRIGGER tg_produto_criado AFTER INSERT ON produto
FOR EACH ROW
BEGIN
    INSERT INTO historico_produto (produto_id, campo, valor_antigo, valor_novo, usuario_id)
    VALUES (NEW.id, 'cadastro', NULL, CONCAT(NEW.nome, ' | venda ', NEW.preco_venda), @usuario_id);
END$$

-- Estoque: as regras do livro-razão, antes de gravar cada movimentação.
CREATE TRIGGER tg_mov_valida BEFORE INSERT ON movimentacao_estoque
FOR EACH ROW
BEGIN
    DECLARE v_perfil TINYINT UNSIGNED;
    DECLARE v_fracao BOOLEAN;
    DECLARE v_ativo_produto BOOLEAN;
    DECLARE v_saldo DECIMAL(14,3);
    DECLARE v_saldo_lote DECIMAL(14,3);

    -- Trava a linha do produto: duas vendas ao mesmo tempo do mesmo produto
    -- esperam uma pela outra, e as duas não "veem" o mesmo saldo antigo.
    SELECT u.aceita_fracao, p.ativo INTO v_fracao, v_ativo_produto
    FROM produto p JOIN unidade u ON u.id = p.unidade_id
    WHERE p.id = NEW.produto_id
    FOR UPDATE;

    -- 1) AJUSTE só por Gerente ou Admin (regra do plano).
    IF NEW.tipo = 'AJUSTE' THEN
        SELECT perfil_id INTO v_perfil FROM usuario WHERE id = NEW.usuario_id;
        IF v_perfil NOT IN (1, 2) THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Ajuste de estoque só pode ser feito por Gerente ou Admin.';
        END IF;
    END IF;

    -- 2) Produto em UN ou CX não aceita quantidade quebrada (1,5 lata).
    IF NOT v_fracao AND NEW.quantidade <> FLOOR(NEW.quantidade) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Esta unidade não aceita quantidade fracionada.';
    END IF;

    -- 3) Produto desativado não vende.
    IF NEW.tipo = 'VENDA' AND NOT v_ativo_produto THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Produto desativado não pode ser vendido.';
    END IF;

    -- 4) O lote precisa ser do mesmo produto.
    IF NEW.lote_id IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM lote WHERE id = NEW.lote_id AND produto_id = NEW.produto_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'O lote informado é de outro produto.';
    END IF;

    -- 5) Saída não pode deixar o saldo negativo (nem do produto, nem do lote).
    IF NEW.quantidade < 0 THEN
        SET v_saldo = fn_saldo_produto(NEW.produto_id);
        IF v_saldo + NEW.quantidade < 0 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Estoque insuficiente para esta saída.';
        END IF;
        IF NEW.lote_id IS NOT NULL THEN
            SELECT COALESCE(SUM(quantidade), 0) INTO v_saldo_lote
            FROM movimentacao_estoque WHERE lote_id = NEW.lote_id;
            IF v_saldo_lote + NEW.quantidade < 0 THEN
                SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Estoque insuficiente neste lote.';
            END IF;
        END IF;
    END IF;
END$$

-- O livro-razão é imutável: errou, lança um AJUSTE com motivo.
CREATE TRIGGER tg_mov_sem_update BEFORE UPDATE ON movimentacao_estoque
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Movimentações não podem ser alteradas. Lance um AJUSTE.';
END$$

CREATE TRIGGER tg_mov_sem_delete BEFORE DELETE ON movimentacao_estoque
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Movimentações não podem ser apagadas. Lance um AJUSTE.';
END$$

-- Salva a projeção do mês atual (média móvel ponderada) para comparar depois
-- com o que realmente vendeu. Pode rodar de novo: atualiza em vez de duplicar.
CREATE PROCEDURE sp_salvar_projecao()
MODIFIES SQL DATA
BEGIN
    INSERT INTO projecao_venda (produto_id, mes_referencia, metodo, quantidade_prevista)
    SELECT produto_id, mes_projetado, 'MEDIA_MOVEL_PONDERADA', projecao
    FROM vw_projecao_mes_atual
    ON DUPLICATE KEY UPDATE
        quantidade_prevista = VALUES(quantidade_prevista),
        calculada_em = UTC_TIMESTAMP(3);
END$$

DELIMITER ;

-- =====================================================================
-- 9. VIEWS: consultas prontas (o "estoque" e os relatórios)
-- =====================================================================

-- ESTOQUE por produto: o saldo é calculado, nunca digitado.
CREATE VIEW vw_estoque_produto AS
SELECT p.id                                   AS produto_id,
       p.nome,
       un.sigla                               AS unidade,
       COALESCE(SUM(m.quantidade), 0)         AS saldo,
       p.estoque_minimo,
       COALESCE(SUM(m.quantidade), 0) < p.estoque_minimo AS abaixo_do_minimo,
       ROUND(COALESCE(SUM(m.quantidade), 0) * p.preco_custo, 2) AS valor_em_estoque,
       p.ativo
FROM produto p
JOIN unidade un ON un.id = p.unidade_id
LEFT JOIN movimentacao_estoque m ON m.produto_id = p.id
GROUP BY p.id, p.nome, un.sigla, p.estoque_minimo, p.preco_custo, p.ativo;

-- ESTOQUE por lote, com quantos dias faltam para vencer.
CREATE VIEW vw_estoque_lote AS
SELECT l.id                           AS lote_id,
       p.id                           AS produto_id,
       p.nome                         AS produto,
       l.codigo,
       l.validade,
       DATEDIFF(l.validade, UTC_DATE()) AS dias_para_vencer,
       COALESCE(SUM(m.quantidade), 0) AS saldo
FROM lote l
JOIN produto p ON p.id = l.produto_id
LEFT JOIN movimentacao_estoque m ON m.lote_id = l.id
GROUP BY l.id, p.id, p.nome, l.codigo, l.validade;

-- Alerta: lotes com saldo que vencem dentro do prazo da loja_config (ou já venceram).
CREATE VIEW vw_alerta_validade AS
SELECT el.*
FROM vw_estoque_lote el
CROSS JOIN loja_config c
WHERE c.id = 1
  AND el.saldo > 0
  AND el.validade IS NOT NULL
  AND el.dias_para_vencer <= c.dias_alerta_validade;

-- Alerta: produtos ativos abaixo do estoque mínimo.
CREATE VIEW vw_alerta_estoque_minimo AS
SELECT produto_id, nome, unidade, saldo, estoque_minimo,
       estoque_minimo - saldo AS falta_para_o_minimo
FROM vw_estoque_produto
WHERE ativo AND abaixo_do_minimo;

-- Margem (sobre o custo) e markup de cada produto.
CREATE VIEW vw_produto_margem AS
SELECT id AS produto_id, nome, preco_custo, preco_venda,
       preco_venda - preco_custo AS lucro_unitario,
       CASE WHEN preco_custo = 0 THEN NULL
            ELSE ROUND((preco_venda - preco_custo) / preco_custo * 100, 2) END AS margem_sobre_custo_pct,
       ROUND((preco_venda - preco_custo) / preco_venda * 100, 2) AS margem_sobre_venda_pct
FROM produto;

-- Vendas finalizadas por produto e por mês.
CREATE VIEW vw_vendas_mensais AS
SELECT vi.produto_id,
       CAST(DATE_FORMAT(v.finalizada_em, '%Y-%m-01') AS DATE) AS mes,
       SUM(vi.quantidade) AS quantidade,
       SUM(vi.total)      AS faturamento
FROM venda_item vi
JOIN venda v ON v.id = vi.venda_id
WHERE v.status = 'FINALIZADA'
GROUP BY vi.produto_id, CAST(DATE_FORMAT(v.finalizada_em, '%Y-%m-01') AS DATE);

-- Curva ABC dos últimos N dias (loja_config.dias_relatorio_abc):
-- A = produtos que somam os primeiros 80% do faturamento, B = até 95%, C = o resto.
CREATE VIEW vw_curva_abc AS
WITH faturamento AS (
    SELECT vi.produto_id, SUM(vi.total) AS valor
    FROM venda_item vi
    JOIN venda v ON v.id = vi.venda_id
    CROSS JOIN loja_config c
    WHERE c.id = 1
      AND v.status = 'FINALIZADA'
      AND v.finalizada_em >= UTC_TIMESTAMP() - INTERVAL c.dias_relatorio_abc DAY
    GROUP BY vi.produto_id
),
acumulado AS (
    SELECT produto_id, valor,
           SUM(valor) OVER (ORDER BY valor DESC, produto_id) AS acumulado,
           SUM(valor) OVER ()                                AS total
    FROM faturamento
)
SELECT a.produto_id,
       p.nome,
       a.valor                                AS faturamento,
       ROUND(a.valor / a.total * 100, 2)      AS participacao_pct,
       ROUND(a.acumulado / a.total * 100, 2)  AS acumulado_pct,
       CASE WHEN (a.acumulado - a.valor) < 0.80 * a.total THEN 'A'
            WHEN (a.acumulado - a.valor) < 0.95 * a.total THEN 'B'
            ELSE 'C' END                      AS classe
FROM acumulado a
JOIN produto p ON p.id = a.produto_id;

-- Projeção do mês atual: média móvel ponderada dos 3 meses completos anteriores.
-- Peso 3 para o mês passado, 2 para o retrasado, 1 para o de 3 meses atrás.
CREATE VIEW vw_projecao_mes_atual AS
SELECT q.produto_id,
       q.nome,
       q.mes_projetado,
       q.qtd_mes_1, q.qtd_mes_2, q.qtd_mes_3,
       ROUND((3 * q.qtd_mes_1 + 2 * q.qtd_mes_2 + 1 * q.qtd_mes_3) / 6, 3) AS projecao
FROM (
    SELECT p.id   AS produto_id,
           p.nome,
           m.inicio AS mes_projetado,
           COALESCE(SUM(CASE WHEN vm.mes = m.inicio - INTERVAL 1 MONTH THEN vm.quantidade END), 0) AS qtd_mes_1,
           COALESCE(SUM(CASE WHEN vm.mes = m.inicio - INTERVAL 2 MONTH THEN vm.quantidade END), 0) AS qtd_mes_2,
           COALESCE(SUM(CASE WHEN vm.mes = m.inicio - INTERVAL 3 MONTH THEN vm.quantidade END), 0) AS qtd_mes_3
    FROM produto p
    CROSS JOIN (SELECT CAST(DATE_FORMAT(UTC_DATE(), '%Y-%m-01') AS DATE) AS inicio) m
    LEFT JOIN vw_vendas_mensais vm
           ON vm.produto_id = p.id
          AND vm.mes >= m.inicio - INTERVAL 3 MONTH
          AND vm.mes <  m.inicio
    WHERE p.ativo
    GROUP BY p.id, p.nome, m.inicio
) q;

-- Fechamento de caixa: dinheiro esperado na gaveta x dinheiro contado.
CREATE VIEW vw_fechamento_caixa AS
SELECT s.id AS sessao_caixa_id,
       cx.nome AS caixa,
       s.aberta_em,
       s.fechada_em,
       s.valor_abertura,
       COALESCE(d.dinheiro_liquido, 0)                    AS dinheiro_das_vendas,
       s.valor_abertura + COALESCE(d.dinheiro_liquido, 0) AS dinheiro_esperado,
       s.valor_fechamento_informado                       AS dinheiro_contado,
       s.valor_fechamento_informado - (s.valor_abertura + COALESCE(d.dinheiro_liquido, 0)) AS diferenca
FROM sessao_caixa s
JOIN caixa cx ON cx.id = s.caixa_id
LEFT JOIN (
    SELECT v.sessao_caixa_id, SUM(pg.valor - pg.troco) AS dinheiro_liquido
    FROM pagamento pg
    JOIN venda v ON v.id = pg.venda_id
    WHERE pg.forma = 'DINHEIRO' AND v.status = 'FINALIZADA'
    GROUP BY v.sessao_caixa_id
) d ON d.sessao_caixa_id = s.id;

-- Conferência: vendas cujo subtotal gravado não bate com a soma dos itens,
-- ou cujo pagamento (descontado o troco) não bate com o total.
-- Se esta view mostrar alguma linha, a aplicação tem um defeito.
CREATE VIEW vw_conferencia_venda AS
SELECT v.id AS venda_id, v.numero, v.status,
       v.subtotal                    AS subtotal_gravado,
       COALESCE(i.soma_itens, 0)     AS soma_dos_itens,
       v.total,
       COALESCE(pg.pago_liquido, 0)  AS pago_liquido
FROM venda v
LEFT JOIN (SELECT venda_id, SUM(total) AS soma_itens FROM venda_item GROUP BY venda_id) i
       ON i.venda_id = v.id
LEFT JOIN (SELECT venda_id, SUM(valor - troco) AS pago_liquido FROM pagamento GROUP BY venda_id) pg
       ON pg.venda_id = v.id
WHERE v.subtotal <> COALESCE(i.soma_itens, 0)
   OR (v.status = 'FINALIZADA' AND v.total <> COALESCE(pg.pago_liquido, 0));
