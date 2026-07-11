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

        SAFE_CAST(share_capital AS FLOAT64) AS share_capital,
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
        SAFE_CAST(REGEXP_EXTRACT(year_quarter, r'^\d{4}-([1-4])$') AS INT64) AS quarter,

        DATE(
            SAFE_CAST(REGEXP_EXTRACT(year_quarter, r'^(\d{4})-[1-4]$') AS INT64),
            CASE SAFE_CAST(REGEXP_EXTRACT(year_quarter, r'^\d{4}-([1-4])$') AS INT64)
                WHEN 1 THEN 3
                WHEN 2 THEN 6
                WHEN 3 THEN 9
                WHEN 4 THEN 12
            END,
            CASE SAFE_CAST(REGEXP_EXTRACT(year_quarter, r'^\d{4}-([1-4])$') AS INT64)
                WHEN 1 THEN 31
                WHEN 2 THEN 30
                WHEN 3 THEN 30
                WHEN 4 THEN 31
            END
        ) AS quarter_end_date

    FROM bs

),

with_action AS (

    SELECT
        p.*,

        COALESCE((
            SELECT EXP(SUM(LN(a.per_share_factor)))
            FROM {{ ref('manual_corporate_actions') }} a
            WHERE a.ticker = p.ticker
              AND p.quarter_end_date < a.effective_date
        ), 1.0) AS per_share_factor,

        COALESCE((
            SELECT EXP(SUM(LN(a.share_factor)))
            FROM {{ ref('manual_corporate_actions') }} a
            WHERE a.ticker = p.ticker
              AND p.quarter_end_date < a.effective_date
        ), 1.0) AS share_factor

    FROM parsed p

),

precalc AS (

    SELECT
        *,

        book_value_per_share * per_share_factor AS adjusted_book_value_per_share,

        SAFE_DIVIDE(share_capital * 1000, 10) * share_factor
            AS shares_outstanding_from_capital,

        SAFE_DIVIDE(
            total_equity * 1000,
            book_value_per_share * per_share_factor
        ) AS shares_outstanding_from_bvps

    FROM with_action

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

        adjusted_book_value_per_share AS book_value_per_share,

        share_capital * 1000 AS share_capital_ntd,
        total_assets * 1000 AS total_assets_ntd,
        total_liabilities * 1000 AS total_liabilities_ntd,
        total_equity * 1000 AS total_equity_ntd,
        current_assets * 1000 AS current_assets_ntd,
        current_liabilities * 1000 AS current_liabilities_ntd,
        retained_earnings * 1000 AS retained_earnings_ntd,
        capital_surplus * 1000 AS capital_surplus_ntd,

        -- 主股數：使用 total_equity / adjusted BVPS。
        -- 這可以正確處理國巨這種面額變更後 share_capital 不再適合用 /10 推股數的情況。
        shares_outstanding_from_bvps AS shares_outstanding,

        -- 保留舊方法作為檢查欄位
        shares_outstanding_from_capital,
        shares_outstanding_from_bvps AS shares_from_bvps,

        SAFE_DIVIDE(
            shares_outstanding_from_capital,
            shares_outstanding_from_bvps
        ) AS share_count_check_ratio,

        SAFE_DIVIDE(current_assets, total_assets) AS current_assets_ratio,
        SAFE_DIVIDE(non_current_assets, total_assets) AS non_current_assets_ratio,

        SAFE_DIVIDE(current_liabilities, total_liabilities) AS current_liabilities_ratio,
        SAFE_DIVIDE(non_current_liabilities, total_liabilities) AS non_current_liabilities_ratio,

        SAFE_DIVIDE(total_liabilities, total_assets) AS debt_ratio,
        SAFE_DIVIDE(total_equity, total_assets) AS equity_ratio,

        SAFE_DIVIDE(total_assets, total_equity) AS financial_leverage,

        SAFE_DIVIDE(current_assets, current_liabilities) AS current_ratio,

        current_assets - current_liabilities AS working_capital,
        (current_assets - current_liabilities) * 1000 AS working_capital_ntd,

        SAFE_DIVIDE(current_assets - current_liabilities, total_assets) AS working_capital_to_assets,
        SAFE_DIVIDE(current_assets - current_liabilities, total_equity) AS working_capital_to_equity,

        SAFE_DIVIDE(retained_earnings, total_equity) AS retained_earnings_to_equity,
        SAFE_DIVIDE(capital_surplus, total_equity) AS capital_surplus_to_equity,
        SAFE_DIVIDE(share_capital, total_equity) AS share_capital_to_equity,
        SAFE_DIVIDE(total_liabilities, total_equity) AS liabilities_to_equity,

        SAFE_DIVIDE(total_assets * 1000, shares_outstanding_from_bvps) AS assets_per_share,
        SAFE_DIVIDE(total_liabilities * 1000, shares_outstanding_from_bvps) AS liabilities_per_share,
        SAFE_DIVIDE(total_equity * 1000, shares_outstanding_from_bvps) AS equity_per_share_calc,
        SAFE_DIVIDE(retained_earnings * 1000, shares_outstanding_from_bvps) AS retained_earnings_per_share,

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
            WHEN adjusted_book_value_per_share > 0
             AND shares_outstanding_from_bvps > 0
             AND SAFE_DIVIDE(
                    shares_outstanding_from_capital,
                    shares_outstanding_from_bvps
                 ) BETWEEN 0.8 AND 1.2
            THEN TRUE
            ELSE FALSE
        END AS is_share_count_reasonable

    FROM precalc

)

SELECT *
FROM calc