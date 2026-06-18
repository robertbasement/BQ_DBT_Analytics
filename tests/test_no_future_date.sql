
SELECT *
FROM {{ ref('mart_vbt_master_dataset') }}
WHERE date > CURRENT_DATE('Asia/Taipei')

-- 不可有未來日期

