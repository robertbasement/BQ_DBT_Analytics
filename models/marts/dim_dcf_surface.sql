{{ config(materialized='table') }}

with params as (

    select
        growth_pct,
        discount_pct,
        terminal_pct,
        high_growth_years,
        estimate_years,

        growth_pct / 100.0 as growth_rate,
        discount_pct / 100.0 as discount_rate,
        terminal_pct / 100.0 as terminal_growth_rate

    from unnest(generate_array(-20, 300, 1)) as growth_pct
    cross join unnest([8, 10, 12]) as discount_pct
    cross join unnest([2]) as terminal_pct
    cross join unnest([3, 5, 10]) as high_growth_years
    cross join unnest([10]) as estimate_years

),

years as (

    select year
    from unnest(generate_array(1, 10)) as year

),

cashflow as (

    select
        p.growth_pct,
        p.discount_pct,
        p.terminal_pct,
        p.growth_rate,
        p.discount_rate,
        p.terminal_growth_rate,
        p.high_growth_years,
        p.estimate_years,
        y.year,

        case
            when y.year <= p.high_growth_years
                then p.growth_rate
            else p.terminal_growth_rate
        end as year_growth_rate

    from params p
    cross join years y
    where y.year <= p.estimate_years

),

compound as (

    select
        *,

        exp(sum(ln(1 + year_growth_rate)) over (
            partition by
                growth_pct,
                discount_pct,
                terminal_pct,
                high_growth_years,
                estimate_years
            order by year
        )) as compound_eps_multiplier

    from cashflow

),

pv as (

    select
        *,
        compound_eps_multiplier / pow(1 + discount_rate, year) as pv_multiplier
    from compound

),

summary as (

    select
        growth_pct,
        discount_pct,
        terminal_pct,
        growth_rate,
        discount_rate,
        terminal_growth_rate,
        high_growth_years,
        estimate_years,

        sum(pv_multiplier) as explicit_pe_multiplier,
        max(case when year = estimate_years then compound_eps_multiplier end) as final_eps_multiplier

    from pv
    group by 1,2,3,4,5,6,7,8

),

final as (

    select
        *,

        final_eps_multiplier
        * (1 + terminal_growth_rate)
        / nullif(discount_rate - terminal_growth_rate, 0)
        / pow(1 + discount_rate, estimate_years)
        as terminal_pe_multiplier

    from summary
    where discount_rate > terminal_growth_rate

)

select
    growth_rate,
    growth_pct as growth_rate_pct,

    discount_rate,
    discount_pct as discount_rate_pct,

    terminal_growth_rate,
    terminal_pct as terminal_growth_rate_pct,

    high_growth_years,
    estimate_years,

    explicit_pe_multiplier,
    terminal_pe_multiplier,
    explicit_pe_multiplier + terminal_pe_multiplier as implied_pe

from final