{{ config(materialized='view') }}

SELECT
  p.* EXCEPT(date),

  COALESCE(
    SAFE.PARSE_DATE('%Y-%m-%d', CAST(date AS STRING)),
    SAFE.PARSE_DATE('%Y%m%d', CAST(date AS STRING))
  ) AS date

FROM {{ source('stock_data', 'daily_prices_partitioned') }} p
WHERE date IS NOT NULL