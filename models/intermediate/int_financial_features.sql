{{ config(materialized='view') }}

WITH base AS (
  SELECT 
    ticker,
    year_quarter,
    LEFT(year_quarter, 4) AS year_label,
    RIGHT(year_quarter, 1) AS quarter_label,
    revenue,
    operating_income,
    eps,
    net_income
  FROM {{ ref('stg_income_statement') }}
),

single_quarter_calc AS (
  SELECT 
    ticker,
    year_quarter,

    CASE 
      WHEN quarter_label = '1' THEN revenue
      ELSE revenue - LAG(revenue) OVER(PARTITION BY ticker, year_label ORDER BY year_quarter)
    END AS q_revenue,

    CASE 
      WHEN quarter_label = '1' THEN operating_income
      ELSE operating_income - LAG(operating_income) OVER(PARTITION BY ticker, year_label ORDER BY year_quarter)
    END AS q_operating_income,

    CASE 
      WHEN quarter_label = '1' THEN eps
      ELSE eps - LAG(eps) OVER(PARTITION BY ticker, year_label ORDER BY year_quarter)
    END AS q_eps

  FROM base
),

ratios_calc AS (
  SELECT
    *,
    SAFE_DIVIDE(q_operating_income, q_revenue) AS operating_margin
  FROM single_quarter_calc
),

signals AS (
  SELECT
    *,
    STDDEV(operating_margin) OVER(
      PARTITION BY ticker
      ORDER BY year_quarter
      ROWS BETWEEN 3 PRECEDING AND CURRENT ROW
    ) AS ebit_volatility,

    MIN(operating_margin) OVER(
      PARTITION BY ticker
      ORDER BY year_quarter
      ROWS BETWEEN 7 PRECEDING AND CURRENT ROW
    ) AS min_margin_8q,

    LAG(operating_margin) OVER(
      PARTITION BY ticker
      ORDER BY year_quarter
    ) AS prev_margin,

    LAG(q_eps, 4) OVER(
      PARTITION BY ticker
      ORDER BY year_quarter
    ) AS last_year_q_eps

  FROM ratios_calc
),

ttm_calc AS (
  SELECT
    *,

    CASE
      WHEN COUNT(q_eps) OVER(
        PARTITION BY ticker
        ORDER BY year_quarter
        ROWS BETWEEN 3 PRECEDING AND CURRENT ROW
      ) = 4
      THEN SUM(q_eps) OVER(
        PARTITION BY ticker
        ORDER BY year_quarter
        ROWS BETWEEN 3 PRECEDING AND CURRENT ROW
      )
    END AS eps_ttm

  FROM signals
)

SELECT
  ticker,
  year_quarter,
  operating_margin,
  ebit_volatility,
  q_eps AS eps,
  eps_ttm,
  SAFE_DIVIDE(q_eps, NULLIF(last_year_q_eps, 0)) - 1 AS eps_yoy_growth,
  IF(min_margin_8q > 0, 1, 0) AS EBIT_signal,
  IF(q_eps > 0, 1, 0) AS EPS_signal,
  IF(operating_margin > prev_margin, 1, 0) AS EBIT_diff_signal,
  IF(ebit_volatility < 0.05, 1, 0) AS EBIT_vol_signal
FROM ttm_calc