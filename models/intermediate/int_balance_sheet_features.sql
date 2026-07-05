{{ config(materialized='view') }}

WITH bs AS (

    SELECT
        ticker,
        company_name,

        SAFE_CAST(current_assets AS FLOAT64) AS current_assets,
        SAFE_CAST(non_current_assets AS FLOAT64) AS non_current_assets,
        SAFE_CAST(total_assets AS FLOAT64) AS total_assets,

        SAFE_CAST(current_liabilities AS FLOAT64) AS current_liabilities,
        SAFE_CAST(non_current_liabilities AS FLOAT64) AS non_current_liabilities,
        SAFE_CAST(total_liabilities AS FLOAT64) AS total_liabilities,

        SAFE_CAST(share_capital AS FLOAT64) AS share_capital,              -- 單位：千元
        SAFE_CAST(capital_surplus AS FLOAT64) AS capital_surplus,
        SAFE_CAST(retained_earnings AS FLOAT64) AS retained_earnings,
        SAFE_CAST(total_equity AS FLOAT64) AS total_equity,

        SAFE_CAST(book_value_per_share AS FLOAT64) AS book_value_per_share,

        year_quarter

    FROM {{ ref('stg_balance_sheet') }}

),

parsed AS (

    SELECT
        *,

        SAFE_CAST(REGEXP_EXTRACT(year_quarter, r'^(\d{4})-[1-4]$') AS INT64) AS year,
        SAFE_CAST(REGEXP_EXTRACT(year_quarter, r'^\d{4}-([1-4])$') AS INT64) AS quarter

    FROM bs

),

calc AS (

    SELECT
        ticker,
        company_name,
        year,
        quarter,
        year_quarter,

        current_assets,
        non_current_assets,
        total_assets,

        current_liabilities,
        non_current_liabilities,
        total_liabilities,

        share_capital,
        capital_surplus,
        retained_earnings,
        total_equity,
        book_value_per_share,

        -- =====================================
        -- Unit normalization
        -- raw 財報金額單位：千元
        -- =====================================

        share_capital * 1000 AS share_capital_ntd,
        total_assets * 1000 AS total_assets_ntd,
        total_liabilities * 1000 AS total_liabilities_ntd,
        total_equity * 1000 AS total_equity_ntd,
        current_assets * 1000 AS current_assets_ntd,
        current_liabilities * 1000 AS current_liabilities_ntd,
        retained_earnings * 1000 AS retained_earnings_ntd,
        capital_surplus * 1000 AS capital_surplus_ntd,

        -- =====================================
        -- Share related
        -- 台股普通股面額通常 10 元
        -- =====================================

        SAFE_DIVIDE(share_capital * 1000, 10) AS shares_outstanding,

        -- 用 BVPS 反推 shares，作為檢查用
        SAFE_DIVIDE(total_equity * 1000, book_value_per_share) AS shares_from_bvps,

        SAFE_DIVIDE(
            SAFE_DIVIDE(share_capital * 1000, 10),
            SAFE_DIVIDE(total_equity * 1000, book_value_per_share)
        ) AS share_count_check_ratio,

        -- =====================================
        -- Balance sheet structure
        -- =====================================

        SAFE_DIVIDE(current_assets, total_assets) AS current_assets_ratio,
        SAFE_DIVIDE(non_current_assets, total_assets) AS non_current_assets_ratio,

        SAFE_DIVIDE(current_liabilities, total_liabilities) AS current_liabilities_ratio,
        SAFE_DIVIDE(non_current_liabilities, total_liabilities) AS non_current_liabilities_ratio,

        SAFE_DIVIDE(total_liabilities, total_assets) AS debt_ratio,
        SAFE_DIVIDE(total_equity, total_assets) AS equity_ratio,

        SAFE_DIVIDE(total_assets, total_equity) AS financial_leverage,

        -- =====================================
        -- Liquidity
        -- =====================================

        SAFE_DIVIDE(current_assets, current_liabilities) AS current_ratio,

        current_assets - current_liabilities AS working_capital,
        (current_assets - current_liabilities) * 1000 AS working_capital_ntd,

        SAFE_DIVIDE(
            current_assets - current_liabilities,
            total_assets
        ) AS working_capital_to_assets,

        SAFE_DIVIDE(
            current_assets - current_liabilities,
            total_equity
        ) AS working_capital_to_equity,

        -- =====================================
        -- Capital structure
        -- =====================================

        SAFE_DIVIDE(retained_earnings, total_equity) AS retained_earnings_to_equity,

        SAFE_DIVIDE(capital_surplus, total_equity) AS capital_surplus_to_equity,

        SAFE_DIVIDE(share_capital, total_equity) AS share_capital_to_equity,

        SAFE_DIVIDE(total_liabilities, total_equity) AS liabilities_to_equity,

        -- =====================================
        -- Per share balance sheet items
        -- =====================================

        SAFE_DIVIDE(total_assets * 1000, SAFE_DIVIDE(share_capital * 1000, 10))
            AS assets_per_share,

        SAFE_DIVIDE(total_liabilities * 1000, SAFE_DIVIDE(share_capital * 1000, 10))
            AS liabilities_per_share,

        SAFE_DIVIDE(total_equity * 1000, SAFE_DIVIDE(share_capital * 1000, 10))
            AS equity_per_share_calc,

        SAFE_DIVIDE(retained_earnings * 1000, SAFE_DIVIDE(share_capital * 1000, 10))
            AS retained_earnings_per_share,

        -- =====================================
        -- Quality flags
        -- =====================================

        CASE
            WHEN total_assets > 0
             AND total_liabilities >= 0
             AND total_equity > 0
             AND share_capital > 0
            THEN TRUE
            ELSE FALSE
        END AS is_valid_balance_sheet,

        CASE
            WHEN ABS(total_assets - total_liabilities - total_equity)
                 <= total_assets * 0.05
            THEN TRUE
            ELSE FALSE
        END AS is_balance_equation_roughly_valid,

        CASE
            WHEN book_value_per_share > 0
             AND SAFE_DIVIDE(
                    SAFE_DIVIDE(share_capital * 1000, 10),
                    SAFE_DIVIDE(total_equity * 1000, book_value_per_share)
                 ) BETWEEN 0.8 AND 1.2
            THEN TRUE
            ELSE FALSE
        END AS is_share_count_reasonable

    FROM parsed

)

SELECT *
FROM calc