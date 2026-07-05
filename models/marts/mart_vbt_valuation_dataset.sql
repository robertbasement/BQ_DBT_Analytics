{{ config(
    materialized='table'
) }}

with base as (

    select
        date,
        ticker,
        d_close,
        eps_ttm,

        safe_divide(d_close, nullif(eps_ttm, 0)) as pe_ttm

    from {{ ref('mart_vbt_master_dataset') }}
    where eps_ttm is not null
      and eps_ttm > 0
      and d_close > 0

),

matched as (

    select
        b.*,

        s.growth_rate_pct as implied_growth_pct,
        s.discount_rate_pct,
        s.terminal_growth_rate_pct,
        s.high_growth_years,
        s.implied_pe,

        abs(b.pe_ttm - s.implied_pe) as pe_diff,

        row_number() over (
            partition by
                b.date,
                b.ticker,
                s.discount_rate_pct,
                s.terminal_growth_rate_pct,
                s.high_growth_years
            order by abs(b.pe_ttm - s.implied_pe)
        ) as rn

    from base b
    join {{ ref('dim_dcf_surface') }} s
      on s.discount_rate_pct = 10
     and s.terminal_growth_rate_pct = 2
     and s.high_growth_years in (3, 5, 10)

),

pivoted as (

    select
        date,
        ticker,
        d_close,
        eps_ttm,
        pe_ttm,

        max(case when high_growth_years = 3 then implied_growth_pct end) as implied_growth_3y_pct,
        max(case when high_growth_years = 5 then implied_growth_pct end) as implied_growth_5y_pct,
        max(case when high_growth_years = 10 then implied_growth_pct end) as implied_growth_10y_pct,

        max(case when high_growth_years = 3 then implied_pe end) as implied_pe_3y,
        max(case when high_growth_years = 5 then implied_pe end) as implied_pe_5y,
        max(case when high_growth_years = 10 then implied_pe end) as implied_pe_10y

    from matched
    where rn = 1
    group by 1,2,3,4,5

)

select *
from pivoted