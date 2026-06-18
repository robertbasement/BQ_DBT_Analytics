{{ config(
    materialized='table',
    partition_by={
      "field": "date",
      "data_type": "date",
      "granularity": "month"
    },
    cluster_by=["ticker"]
) }}

WITH flattened AS (

    SELECT
        date,
        ticker,

        MAX(open) AS d_open,
        MAX(high) AS d_high,
        MAX(low) AS d_low,
        MAX(adj_close) AS d_close,
        MAX(volume) AS d_vol,

        MAX(ma20) AS ma20,
        MAX(ma60) AS ma60,
        MAX(bias20) AS bias20,

        ANY_VALUE(rev_box) AS r,
        ANY_VALUE(fin_box) AS f

    FROM {{ ref('int_vbt_stack') }}
    GROUP BY date, ticker

),

filled AS (

    SELECT
        date,
        ticker,

        d_open,
        d_high,
        d_low,
        d_close,
        d_vol,

        ma20,
        ma60,
        bias20,

        LAST_VALUE(r.revenue IGNORE NULLS) OVER (
            PARTITION BY ticker
            ORDER BY date
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS revenue,

        LAST_VALUE(r.yoy_growth_pct IGNORE NULLS) OVER (
            PARTITION BY ticker
            ORDER BY date
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS yoy_growth,

        LAST_VALUE(r.mom_growth_pct IGNORE NULLS) OVER (
            PARTITION BY ticker
            ORDER BY date
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS mom_growth_pct,

        LAST_VALUE(r.ytd_growth_pct IGNORE NULLS) OVER (
            PARTITION BY ticker
            ORDER BY date
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS ytd_growth_pct,

        LAST_VALUE(r.yoy_positive_streak_count IGNORE NULLS) OVER (
            PARTITION BY ticker
            ORDER BY date
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS yoy_positive_streak_count,

        LAST_VALUE(r.yoy_triple_increase_signal IGNORE NULLS) OVER (
            PARTITION BY ticker
            ORDER BY date
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS rev_triple_sig,

        LAST_VALUE(f.eps IGNORE NULLS) OVER (
            PARTITION BY ticker
            ORDER BY date
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS eps,

        LAST_VALUE(f.operating_margin IGNORE NULLS) OVER (
            PARTITION BY ticker
            ORDER BY date
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS op_margin,

        LAST_VALUE(f.EBIT_signal IGNORE NULLS) OVER (
            PARTITION BY ticker
            ORDER BY date
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS EBIT_signal,

        LAST_VALUE(f.EPS_signal IGNORE NULLS) OVER (
            PARTITION BY ticker
            ORDER BY date
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS EPS_signal,

        LAST_VALUE(f.EBIT_vol_signal IGNORE NULLS) OVER (
            PARTITION BY ticker
            ORDER BY date
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS EBIT_vol_signal,

        LAST_VALUE(r.data_month_label IGNORE NULLS) OVER (
            PARTITION BY ticker
            ORDER BY date
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS revenue_month,

        LAST_VALUE(f.data_quarter_label IGNORE NULLS) OVER (
            PARTITION BY ticker
            ORDER BY date
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS report_quarter

    FROM flattened

),

final AS (

    SELECT
        *,

        SAFE_DIVIDE(
            LEAD(d_close, 1) OVER (
                PARTITION BY ticker
                ORDER BY date
            ),
            d_close
        ) - 1 AS ret_1d,

        SAFE_DIVIDE(
            LEAD(d_close, 5) OVER (
                PARTITION BY ticker
                ORDER BY date
            ),
            d_close
        ) - 1 AS ret_5d,

        SAFE_DIVIDE(
            LEAD(d_close, 10) OVER (
                PARTITION BY ticker
                ORDER BY date
            ),
            d_close
        ) - 1 AS ret_10d,

        SAFE_DIVIDE(
            LEAD(d_close, 20) OVER (
                PARTITION BY ticker
                ORDER BY date
            ),
            d_close
        ) - 1 AS ret_20d

    FROM filled
    WHERE date >= DATE '2010-01-01'

)

SELECT *
FROM final