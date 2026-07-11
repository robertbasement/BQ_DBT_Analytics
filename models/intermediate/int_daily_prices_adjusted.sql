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
  c.* EXCEPT(daily_factor, rev_cum_factor),

  c.close
  * c.rev_cum_factor
  * COALESCE((
      SELECT EXP(SUM(LN(a.price_factor)))
      FROM {{ ref('manual_corporate_actions') }} a
      WHERE a.ticker = c.ticker
        AND c.date < a.effective_date
    ), 1.0) AS adj_close

FROM cumulative_calculation c