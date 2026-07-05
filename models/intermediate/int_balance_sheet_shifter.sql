{{ config(materialized='view') }}

WITH bs AS (

    SELECT *
    FROM {{ ref('int_balance_sheet_features') }}

),

with_deadline AS (

    SELECT
        *,

        CASE
            WHEN quarter = 1 THEN DATE(year, 5, 16)
            WHEN quarter = 2 THEN DATE(year, 8, 16)
            WHEN quarter = 3 THEN DATE(year, 11, 15)
            WHEN quarter = 4 THEN DATE(year + 1, 4, 1)
        END AS deadline_date

    FROM bs

)

SELECT
    deadline_date AS date,
    ticker,

    STRUCT(
        current_assets,
        non_current_assets,
        total_assets,

        current_liabilities,
        non_current_liabilities,
        total_liabilities,

        share_capital,
        share_capital_ntd,
        shares_outstanding,

        capital_surplus,
        retained_earnings,
        total_equity,

        book_value_per_share,

        debt_ratio,
        equity_ratio,
        current_ratio,

        year_quarter
    ) AS bs_box

FROM with_deadline
WHERE deadline_date IS NOT NULL