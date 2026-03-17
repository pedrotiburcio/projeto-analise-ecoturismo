-- Relatório KPI's ECOTURISMO

-- 1. Receita total por mês
SELECT 
  EXTRACT(YEAR FROM r.data_reserva) AS ano,
  FORMAT_DATE('%B', r.data_reserva) AS mes,
  ROUND(SUM(o.preco * r.qtd_pessoas), 2) AS faturamento_total
FROM `projeto-ecoturismo.dataset.reservas` r
JOIN `projeto-ecoturismo.dataset.ofertas` o
  ON r.id_oferta = o.id_oferta
WHERE r.status = "concluída"
GROUP BY 1, 2, EXTRACT(MONTH FROM r.data_reserva)
ORDER BY 1 DESC, EXTRACT(MONTH FROM r.data_reserva) DESC;

-- Receita total por mês, segmentando por atividades sustentáveis e não sustentáveis
SELECT 
  EXTRACT(YEAR FROM r.data_reserva) AS ano,
  FORMAT_DATE('%B', r.data_reserva) AS mes,
  ROUND(
    SUM(
      CASE 
        WHEN EXISTS (
          SELECT 1
          FROM `projeto-ecoturismo.dataset.oferta_pratica` op
          WHERE op.id_oferta = o.id_oferta
        ) THEN o.preco * r.qtd_pessoas
        ELSE 0
      END
    ), 2
  ) AS receita_sustentavel,
  ROUND(
    SUM(
      CASE 
        WHEN NOT EXISTS (
          SELECT 1
          FROM `projeto-ecoturismo.dataset.oferta_pratica` op
          WHERE op.id_oferta = o.id_oferta
        ) THEN o.preco * r.qtd_pessoas
        ELSE 0
      END
    ), 2
  ) AS receita_nao_sustentavel,
  ROUND(SUM(o.preco * r.qtd_pessoas), 2) AS receita_total
FROM `projeto-ecoturismo.dataset.reservas` r
JOIN `projeto-ecoturismo.dataset.ofertas` o
  ON r.id_oferta = o.id_oferta
WHERE r.status = "concluída"
GROUP BY 1, 2, EXTRACT(MONTH FROM r.data_reserva)
ORDER BY 1 DESC, EXTRACT(MONTH FROM r.data_reserva) DESC;

-- Identifica quanto a empresa está faturando com experiências sustentáveis
SELECT 
  ROUND(SUM(o.preco * r.qtd_pessoas), 2) AS faturamento_total
FROM `projeto-ecoturismo.dataset.reservas` r
JOIN `projeto-ecoturismo.dataset.ofertas` o
  ON r.id_oferta = o.id_oferta
WHERE r.status = "concluída"
  AND EXISTS (
    SELECT 1
    FROM `projeto-ecoturismo.dataset.oferta_pratica` op
    WHERE o.id_oferta = op.id_oferta
  );

-- 2. Valor médio gasto por pessoa em uma reserva
SELECT 
  ROUND(SUM(o.preco * r.qtd_pessoas) / SUM(r.qtd_pessoas), 2) AS valor_medio_por_pessoa
FROM `projeto-ecoturismo.dataset.reservas` r
JOIN `projeto-ecoturismo.dataset.ofertas` o
  ON r.id_oferta = o.id_oferta
WHERE r.status = "concluída";

-- Mediana de preço das ofertas
SELECT 
  PERCENTILE_CONT(preco, 0.5) OVER() AS mediana_preco
FROM `projeto-ecoturismo.dataset.ofertas`
LIMIT 1;

-- 3. Distribuição de reservas por tipo de oferta (Qual tipo é mais popular?)
SELECT 
  o.tipo_oferta,
  COUNT(r.id_oferta) AS quant_reservas,
  SUM(r.qtd_pessoas) AS quant_pessoas
FROM `projeto-ecoturismo.dataset.reservas` r
JOIN `projeto-ecoturismo.dataset.ofertas` o
  ON r.id_oferta = o.id_oferta
WHERE r.status = "concluída"
GROUP BY o.tipo_oferta
ORDER BY o.tipo_oferta DESC;

-- 4. Taxa de repetição de clientes
WITH base_reservas AS (
  SELECT
    id_cliente,
    COUNT(id_reserva) AS qtd_reservas
  FROM `projeto-ecoturismo.dataset.reservas`
  WHERE status = "concluída"
  GROUP BY id_cliente
),
metricas AS (
  SELECT
    COUNT(*) AS total_clientes,
    COUNTIF(qtd_reservas > 1) AS total_fieis
  FROM base_reservas
)
SELECT
  total_clientes,
  total_fieis,
  ROUND(SAFE_DIVIDE(total_fieis, total_clientes) * 100, 2) AS percentual_fidelidade
FROM metricas;

-- 5. Avaliação média de ofertas
CREATE OR REPLACE VIEW `projeto-ecoturismo.dataset.vw_nota_media_por_oferta` AS
SELECT
  o.id_oferta,
  o.titulo,
  ROUND(AVG(a.nota), 2) AS nota_media
FROM `projeto-ecoturismo.dataset.ofertas` o
JOIN `projeto-ecoturismo.dataset.avaliacoes` a
  ON o.id_oferta = a.id_oferta
GROUP BY 1, 2;

-- TOP 10 melhores ofertas avaliadas
SELECT *
FROM `projeto-ecoturismo.dataset.vw_nota_media_por_oferta`
ORDER BY nota_media DESC
LIMIT 10;

-- TOP 10 piores ofertas avaliadas
SELECT *
FROM `projeto-ecoturismo.dataset.vw_nota_media_por_oferta`
ORDER BY nota_media ASC
LIMIT 10;

-- 6. Índice de ofertas com adoção de práticas sustentáveis (Pelo menos 1 prática sustentável)
SELECT
  COUNT(DISTINCT o.id_oferta) AS total_ofertas,
  COUNT(DISTINCT op.id_oferta) AS ofertas_sustentaveis,
  ROUND(
    SAFE_DIVIDE(COUNT(DISTINCT op.id_oferta), COUNT(DISTINCT o.id_oferta)) * 100,
    2
  ) AS percentual
FROM `projeto-ecoturismo.dataset.ofertas` o
LEFT JOIN `projeto-ecoturismo.dataset.oferta_pratica` op
  ON o.id_oferta = op.id_oferta;

-- 7. Práticas sustentáveis mais populares
CREATE OR REPLACE VIEW `projeto-ecoturismo.dataset.vw_praticas_populares` AS
SELECT
  ps.nome AS pratica_sustentavel,
  COUNT(r.id_reserva) AS total_vendas
FROM `projeto-ecoturismo.dataset.reservas` r
JOIN `projeto-ecoturismo.dataset.oferta_pratica` op
  ON r.id_oferta = op.id_oferta
JOIN `projeto-ecoturismo.dataset.praticas_sustentaveis` ps
  ON op.id_pratica = ps.id_pratica
WHERE r.status = "concluída"
GROUP BY 1;

-- TOP 5 práticas sustentáveis mais populares
SELECT *
FROM `projeto-ecoturismo.dataset.vw_praticas_populares`
ORDER BY 2 DESC
LIMIT 5;

-- 8. Tempo médio (em dias) entre reservas dos clientes recorrentes 
WITH clientes_recorrentes AS (
  SELECT
    id_cliente,
    COUNT(*) AS qtd_reservas
  FROM `projeto-ecoturismo.dataset.reservas`
  WHERE status = "concluída"
  GROUP BY id_cliente
  HAVING COUNT(*) > 1
),
reservas_clientes_recorrentes AS (
  SELECT
    r.id_cliente,
    r.data_reserva
  FROM `projeto-ecoturismo.dataset.reservas` r
  JOIN clientes_recorrentes cr
    ON r.id_cliente = cr.id_cliente
  WHERE r.status = "concluída"
),
comparativo_reservas AS (
  SELECT
    *,
    LAG(data_reserva) OVER (PARTITION BY id_cliente ORDER BY data_reserva) AS data_reserva_anterior
  FROM reservas_clientes_recorrentes
)
SELECT DISTINCT
  ROUND(AVG(DATE_DIFF(data_reserva, data_reserva_anterior, DAY)) OVER(), 2) AS frequencia_reserva,
  PERCENTILE_CONT(DATE_DIFF(data_reserva, data_reserva_anterior, DAY), 0.5) OVER() AS mediana_dias_retorno
FROM comparativo_reservas
WHERE data_reserva_anterior IS NOT NULL;

-- 9. Desempenho médio dos operadores por categoria de oferta
CREATE OR REPLACE VIEW `projeto-ecoturismo.dataset.vw_desempenho_operadores_por_categoria` AS
SELECT
  op.id_operador,
  op.nome_fantasia,
  o.tipo_oferta,
  ROUND(AVG(a.nota), 2) AS nota_media,
  COUNT(a.id_avaliacao) AS total_avaliacoes
FROM `projeto-ecoturismo.dataset.ofertas` o
JOIN `projeto-ecoturismo.dataset.avaliacoes` a
  ON o.id_oferta = a.id_oferta
JOIN `projeto-ecoturismo.dataset.operadores` op
  ON o.id_operador = op.id_operador
GROUP BY op.id_operador, op.nome_fantasia, o.tipo_oferta;

-- Top 10 operadores em atividade
SELECT *
FROM `projeto-ecoturismo.dataset.vw_desempenho_operadores_por_categoria`
WHERE tipo_oferta = "atividade"
ORDER BY nota_media DESC
LIMIT 10;

-- Top 10 operadores em hospedagem
SELECT *
FROM `projeto-ecoturismo.dataset.vw_desempenho_operadores_por_categoria`
WHERE tipo_oferta = "hospedagem"
ORDER BY nota_media DESC
LIMIT 10;

-- 10. Faturamento total
SELECT 
  SUM(faturamento_total) AS faturamento_total
FROM (
  SELECT
    EXTRACT(YEAR FROM r.data_reserva) AS ano,
    FORMAT_DATE('%B', r.data_reserva) AS mes,
    ROUND(SUM(o.preco * r.qtd_pessoas), 2) AS faturamento_total
  FROM `projeto-ecoturismo.dataset.reservas` r
  JOIN `projeto-ecoturismo.dataset.ofertas` o
    ON r.id_oferta = o.id_oferta
  WHERE r.status = "concluída"
  GROUP BY 1, 2, EXTRACT(MONTH FROM r.data_reserva)
);