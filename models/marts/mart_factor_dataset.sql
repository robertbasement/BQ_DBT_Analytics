{{ config(
    materialized='table',
    partition_by={
      "field": "date",
      "data_type": "date",
      "granularity": "month"
    },
    cluster_by=["ticker"]
) }}

with base as (

    select
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

        revenue,
        yoy_growth,
        mom_growth_pct,
        ytd_growth_pct,
        yoy_positive_streak_count,
        rev_triple_sig,

        eps,
        eps_ttm,
        eps_yoy_growth,
        pe_ttm,

        op_margin,
        EBIT_signal,
        EPS_signal,
        EBIT_vol_signal,

        revenue_month,
        report_quarter,

        ret_1d,
        ret_5d,
        ret_10d,
        ret_20d

    from {{ ref('mart_vbt_master_dataset') }}
    where date >= date '2010-01-01'
      and d_close > 0

),

valuation as (

    select
        date,
        ticker,

        implied_growth_3y_pct,
        implied_growth_5y_pct,
        implied_growth_10y_pct,

        implied_pe_3y,
        implied_pe_5y,
        implied_pe_10y

    from {{ ref('mart_vbt_valuation_dataset') }}

),

joined as (

    select
        b.*,

        v.implied_growth_3y_pct,
        v.implied_growth_5y_pct,
        v.implied_growth_10y_pct,

        v.implied_pe_3y,
        v.implied_pe_5y,
        v.implied_pe_10y

    from base b
    left join valuation v
      on b.date = v.date
     and b.ticker = v.ticker

),

features as (

    select
        *,

        safe_divide(d_close, ma20) - 1 as price_ma20_gap,
        safe_divide(d_close, ma60) - 1 as price_ma60_gap,

        case
            when eps_ttm is null or eps_ttm <= 0 then 1
            else 0
        end as eps_ttm_invalid_flag,

        case
            when implied_growth_5y_pct = 500 then 1
            else 0
        end as implied_growth_5y_upper_bound_flag,

        case
            when implied_growth_5y_pct = -20 then 1
            else 0
        end as implied_growth_5y_lower_bound_flag

    from joined

)

select
    date,
    ticker,

    d_open,
    d_high,
    d_low,
    d_close,
    d_vol,

    -- technical factors
    ma20,
    ma60,
    bias20,
    price_ma20_gap,
    price_ma60_gap,

    -- revenue factors
    revenue,
    yoy_growth,
    mom_growth_pct,
    ytd_growth_pct,
    yoy_positive_streak_count,
    rev_triple_sig,

    -- financial factors
    eps,
    eps_ttm,
    eps_yoy_growth,
    op_margin,
    EBIT_signal,
    EPS_signal,
    EBIT_vol_signal,

    -- valuation factors
    pe_ttm,
    implied_growth_3y_pct,
    implied_growth_5y_pct,
    implied_growth_10y_pct,
    implied_pe_3y,
    implied_pe_5y,
    implied_pe_10y,

    eps_ttm_invalid_flag,
    implied_growth_5y_upper_bound_flag,
    implied_growth_5y_lower_bound_flag,

    -- labels / data freshness
    revenue_month,
    report_quarter,

    -- forward returns
    ret_1d,
    ret_5d,
    ret_10d,
    ret_20d

from features