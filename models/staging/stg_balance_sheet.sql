{{ config(materialized='view') }}

SELECT
    ticker,
    company_name,

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

    year_quarter

FROM {{ source('stock_data', 'balance_sheet') }}