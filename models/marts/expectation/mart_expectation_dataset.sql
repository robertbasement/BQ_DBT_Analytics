{{ config(
    materialized='table',
    partition_by={
      "field": "date",
      "data_type": "date",
      "granularity": "month"
    },
    cluster_by=["ticker"]
) }}

WITH base AS (

    SELECT
        *,

        CAST(
            ROUND(pe_ttm * 10)
            AS INT64
        ) AS pe_x10,

        ROUND(pe_ttm, 1) AS pe_rounded

    FROM {{ ref('mart_expectation_features') }}

    WHERE date >= DATE '2010-01-01'

      AND d_close IS NOT NULL

      AND eps_ttm IS NOT NULL
      AND eps_ttm > 0

      AND pe_ttm IS NOT NULL
      AND pe_ttm > 0
      AND pe_ttm <= 300

),

/*
 * 根據目前 PE，查找市場價格所隱含的 EPS 成長率。
 */
joined AS (

    SELECT
        b.*,

        l.implied_growth_pct,
        l.implied_growth,
        l.implied_pe,
        l.pe_diff,

        l.discount_rate_pct,
        l.terminal_growth_rate_pct,
        l.high_growth_years,
        l.estimate_years

    FROM base b

    LEFT JOIN {{ ref('dim_dcf_lookup') }} l
        ON b.pe_x10 = l.pe_x10

       AND l.discount_rate_pct = 10
       AND l.terminal_growth_rate_pct = 2
       AND l.high_growth_years = 5

),

final AS (

    SELECT
        date,
        ticker,

        /*
         * Price and valuation
         */
        d_close,

        eps,
        eps_ttm,

        pe_ttm,
        pe_rounded,
        pe_x10,

        pb_ratio,

        /*
         * Monthly revenue observations
         */
        revenue,
        revenue_month,

        monthly_revenue_ttm,

        revenue_yoy_3m_avg,
        revenue_yoy_6m_avg,
        revenue_acceleration,
        expected_revenue_growth,

        /*
         * Financial statement information
         */
        report_quarter,

        financial_q_revenue,
        financial_revenue_ttm,

        financial_q_operating_income,
        financial_operating_income_ttm,

        financial_q_net_income,
        financial_net_income_ttm,

        op_margin,
        operating_margin_ttm,

        net_margin,
        net_margin_ttm,

        ebit_volatility,
        net_margin_volatility,

        /*
         * Capital and balance-sheet information
         */
        shares_outstanding,
        book_value_per_share,

        debt_ratio,
        equity_ratio,
        current_ratio,

        /*
         * Forward fundamental estimates
         */
        forward_revenue_ttm,
        forward_net_income,
        forward_eps,
        forward_constant_growth,

        /*
         * Market-implied growth
         */
        implied_growth_pct,
        implied_growth,
        implied_pe,
        pe_diff,

        discount_rate_pct,
        terminal_growth_rate_pct,
        high_growth_years,
        estimate_years,

        /*
         * Fundamental expectation versus market expectation
         */
        forward_constant_growth
            - implied_growth
            AS expectation_gap,

        /*
         * Signals
         */
        CASE
            WHEN forward_constant_growth IS NULL
                THEN NULL

            WHEN forward_constant_growth >= 0.3
                THEN 1

            WHEN forward_constant_growth >= 0.1
                THEN 0

            ELSE -1
        END AS forward_constant_growth_signal,

        CASE
            WHEN expected_revenue_growth IS NULL
                THEN NULL

            WHEN expected_revenue_growth >= 0.3
                THEN 1

            WHEN expected_revenue_growth >= 0.1
                THEN 0

            ELSE -1
        END AS expected_revenue_growth_signal,

        CASE
            WHEN forward_constant_growth - implied_growth IS NULL
                THEN NULL

            WHEN forward_constant_growth - implied_growth >= 0.2
                THEN 1

            WHEN forward_constant_growth - implied_growth >= 0
                THEN 0

            ELSE -1
        END AS expectation_gap_signal

    FROM joined

)

SELECT *
FROM final