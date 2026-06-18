SELECT
    date,
    ticker,
    COUNT(*) AS cnt
FROM {{ ref('mart_vbt_master_dataset') }}
GROUP BY 1,2
HAVING COUNT(*) > 1

-- (date,ticker)
-- 不可重複
