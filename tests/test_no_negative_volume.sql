SELECT *
FROM {{ ref('mart_vbt_master_dataset') }}
WHERE d_vol < 0

-- 成交量不得 < 0

