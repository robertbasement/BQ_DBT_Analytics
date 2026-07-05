{{ config(materialized='table') }}

WITH pe_grid AS (

    SELECT
        pe_x10,
        pe_x10 / 10.0 AS pe_rounded
    FROM UNNEST(GENERATE_ARRAY(1, 3000, 1)) AS pe_x10

),

candidates AS (

    SELECT
        p.pe_x10,
        p.pe_rounded,

        s.discount_rate_pct,
        s.terminal_growth_rate_pct,
        s.high_growth_years,
        s.estimate_years,

        s.growth_rate_pct AS implied_growth_pct,
        s.implied_pe,

        ABS(p.pe_rounded - s.implied_pe) AS pe_diff

    FROM pe_grid p
    JOIN {{ ref('dim_dcf_surface') }} s
      ON s.implied_pe IS NOT NULL
     AND s.implied_pe > 0

),

ranked AS (

    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY
                pe_x10,
                discount_rate_pct,
                terminal_growth_rate_pct,
                high_growth_years,
                estimate_years
            ORDER BY pe_diff ASC
        ) AS rn
    FROM candidates

)

SELECT
    pe_x10,
    pe_rounded,

    discount_rate_pct,
    terminal_growth_rate_pct,
    high_growth_years,
    estimate_years,

    implied_growth_pct,
    implied_growth_pct / 100.0 AS implied_growth,

    implied_pe,
    pe_diff

FROM ranked
WHERE rn = 1