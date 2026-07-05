{{ config(materialized='view') }}

WITH base AS (

    SELECT *
    FROM {{ ref('mart_vbt_master_dataset') }}

),

monthly_revenue AS (

    SELECT
        ticker,
        revenue_month,
        MIN(date) AS revenue_available_date,
        ANY_VALUE(revenue) AS revenue,
        ANY_VALUE(yoy_growth) AS yoy_growth
    FROM base
    WHERE revenue_month IS NOT NULL
      AND revenue IS NOT NULL
    GROUP BY ticker, revenue_month

),

monthly_features_1 AS (

    SELECT
        *,

        SUM(revenue) OVER (
            PARTITION BY ticker
            ORDER BY revenue_available_date
            ROWS BETWEEN 11 PRECEDING AND CURRENT ROW
        ) AS revenue_ttm,

        AVG(
            CASE
                WHEN ABS(yoy_growth) > 1 THEN yoy_growth / 100
                ELSE yoy_growth
            END
        ) OVER (
            PARTITION BY ticker
            ORDER BY revenue_available_date
            ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
        ) AS revenue_yoy_3m_avg,

        AVG(
            CASE
                WHEN ABS(yoy_growth) > 1 THEN yoy_growth / 100
                ELSE yoy_growth
            END
        ) OVER (
            PARTITION BY ticker
            ORDER BY revenue_available_date
            ROWS BETWEEN 5 PRECEDING AND CURRENT ROW
        ) AS revenue_yoy_6m_avg

    FROM monthly_revenue

),

monthly_features AS (

    SELECT
        *,

        revenue_yoy_3m_avg - revenue_yoy_6m_avg AS revenue_acceleration,

        GREATEST(
            -0.5,
            LEAST(
                1.0,
                revenue_yoy_6m_avg + 0.5 * (revenue_yoy_3m_avg - revenue_yoy_6m_avg)
            )
        ) AS expected_revenue_growth

    FROM monthly_features_1

),

quarterly_financial AS (

    SELECT
        ticker,
        report_quarter,
        MIN(date) AS report_available_date,
        ANY_VALUE(op_margin) AS op_margin,
        ANY_VALUE(eps_ttm) AS eps_ttm
    FROM base
    WHERE report_quarter IS NOT NULL
    GROUP BY ticker, report_quarter

),

quarterly_features AS (

    SELECT
        *,

        AVG(
            CASE
                WHEN ABS(op_margin) > 1 THEN op_margin / 100
                ELSE op_margin
            END
        ) OVER (
            PARTITION BY ticker
            ORDER BY report_available_date
            ROWS BETWEEN 3 PRECEDING AND CURRENT ROW
        ) AS expected_margin

    FROM quarterly_financial

),

daily AS (

    SELECT
        b.date,
        b.ticker,

        b.d_close,
        b.eps,
        b.eps_ttm,
        b.pe_ttm,
        b.pb_ratio,

        b.revenue,
        b.revenue_month,
        b.report_quarter,
        b.op_margin,

        b.shares_outstanding,
        b.book_value_per_share,
        b.debt_ratio,
        b.equity_ratio,
        b.current_ratio,

        mf.revenue_ttm,
        mf.revenue_yoy_3m_avg,
        mf.revenue_yoy_6m_avg,
        mf.revenue_acceleration,
        mf.expected_revenue_growth,

        qf.expected_margin,

        mf.revenue_ttm * (1 + mf.expected_revenue_growth) AS forward_revenue_ttm,

        mf.revenue_ttm
            * (1 + mf.expected_revenue_growth)
            * qf.expected_margin AS forward_income_proxy,

        SAFE_DIVIDE(
            mf.revenue_ttm
                * (1 + mf.expected_revenue_growth)
                * qf.expected_margin
                * 1000,
            b.shares_outstanding
        ) AS forward_eps,

        SAFE_DIVIDE(
            SAFE_DIVIDE(
                mf.revenue_ttm
                    * (1 + mf.expected_revenue_growth)
                    * qf.expected_margin
                    * 1000,
                b.shares_outstanding
            ),
            NULLIF(b.eps_ttm, 0)
        ) - 1 AS forward_constant_growth,

       

        -- backward compatibility
        -- mf.revenue_ttm * (1 + mf.expected_revenue_growth) AS expected_revenue_ttm,

        -- mf.revenue_ttm
        --     * (1 + mf.expected_revenue_growth)
        --     * qf.expected_margin AS expected_income_proxy,

        -- SAFE_DIVIDE(
        --     mf.revenue_ttm
        --         * (1 + mf.expected_revenue_growth)
        --         * qf.expected_margin
        --         * 1000,
        --     b.shares_outstanding
        -- ) AS expected_eps,

        -- SAFE_DIVIDE(
        --     SAFE_DIVIDE(
        --         mf.revenue_ttm
        --             * (1 + mf.expected_revenue_growth)
        --             * qf.expected_margin
        --             * 1000,
        --         b.shares_outstanding
        --     ),
        --     NULLIF(b.eps_ttm, 0)
        -- ) - 1 AS expected_eps_growth

    FROM base b
    LEFT JOIN monthly_features mf
        ON b.ticker = mf.ticker
       AND b.revenue_month = mf.revenue_month
    LEFT JOIN quarterly_features qf
        ON b.ticker = qf.ticker
       AND b.report_quarter = qf.report_quarter

)

SELECT *
FROM daily