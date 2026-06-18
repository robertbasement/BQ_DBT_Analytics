
{{ config(materialized='view') }}



WITH raw_ranked AS (
  SELECT 
    *,
    /* 根據 ticker 和 year_month 群組編號 */
    ROW_NUMBER() OVER(
      PARTITION BY ticker, year_month 
      ORDER BY revenue DESC -- 這裡假設取數值較大或最新的那一筆，可依實際資料狀況調整
    ) as row_num
  FROM 
    {{source('stock_data', 'monthly_revenue')}}
)
SELECT 
    ticker,
    company_name,
    year_month,
    CAST(revenue AS INT64) AS revenue,
    SAFE_CAST(revenue_prev_month AS INT64) AS revenue_prev_month,
    CAST(revenue_last_year AS INT64) AS revenue_last_year,
    SAFE_CAST(mom_growth_pct AS FLOAT64) AS mom_growth_pct,
    SAFE_CAST(yoy_growth_pct AS FLOAT64) AS yoy_growth_pct,
    CAST(revenue_ytd AS INT64) AS revenue_ytd,
    CAST(revenue_ytd_last_year AS INT64) AS revenue_ytd_last_year,
    SAFE_CAST(ytd_growth_pct AS FLOAT64) AS ytd_growth_pct
FROM 
    raw_ranked
WHERE 
    row_num = 1