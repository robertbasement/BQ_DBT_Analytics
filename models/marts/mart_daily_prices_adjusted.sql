{{ config(
    materialized='table',
    partition_by={
      "field": "date",
      "data_type": "date",
      "granularity": "month"
    },
    cluster_by=["ticker"]
) }}

WITH price_joined AS (

  SELECT
    p.*,
    COALESCE(d.daily_factor, 1.0) AS daily_factor
  FROM {{ ref('stg_daily_prices_raw') }} p
  LEFT JOIN {{ ref('stg_dividend_factor') }} d
    ON p.date = d.ex_date
   AND p.ticker = d.ticker
  WHERE p.date >= DATE '2000-01-01'

),

cumulative_calculation AS (

  SELECT
    *,
    EXP(
      SUM(LN(daily_factor)) OVER (
        PARTITION BY ticker
        ORDER BY date DESC
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
      )
    ) AS rev_cum_factor
  FROM price_joined

)

SELECT
  * EXCEPT(daily_factor, rev_cum_factor),

  CASE
    WHEN ticker = '0050'
     AND date >= DATE '2025-06-18'
    THEN close * rev_cum_factor * 4
    ELSE close * rev_cum_factor
  END AS adj_close

FROM cumulative_calculation