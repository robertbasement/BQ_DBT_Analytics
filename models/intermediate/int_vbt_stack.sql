-- models/intermediate/int_vbt_stack.sql

{{ config(materialized='view') }}

SELECT 
  date,
  ticker,
  open,
  high,
  low,
  adj_close,
  volume,
  ma20,
  ma60,
  bias20,
  day_amplitude,
  CAST(NULL AS STRUCT<
    revenue INT64, 
    yoy_growth_pct FLOAT64, 
    mom_growth_pct FLOAT64,
    ytd_growth_pct FLOAT64,
    yoy_triple_increase_signal INT64,
    yoy_positive_streak_count INT64,
    data_month_label STRING
  >) AS rev_box,
  CAST(NULL AS STRUCT<
    operating_margin FLOAT64,
    ebit_volatility FLOAT64,
    eps FLOAT64,
    EBIT_signal INT64,
    EPS_signal INT64,
    EBIT_diff_signal INT64,
    EBIT_vol_signal INT64,
    data_quarter_label STRING
  >) AS fin_box
FROM {{ ref('int_daily_indicators') }}

UNION ALL

SELECT
  date,
  ticker, 
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  rev_box,
  NULL
FROM {{ ref('int_monthly_revenue_shifter') }}

UNION ALL

SELECT
  date,
  ticker, 
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  fin_box
FROM {{ ref('int_financial_shifter') }}