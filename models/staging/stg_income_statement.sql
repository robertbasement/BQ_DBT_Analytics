{{ config(materialized='view') }}

WITH raw_ranked AS (
  SELECT 
    *,
    ROW_NUMBER() OVER(
      PARTITION BY ticker, year_quarter
      ORDER BY ticker
    ) AS row_num
  FROM {{ source('stock_data', 'income_statement') }}
)

SELECT 
  ticker,
  company_name,
  year_quarter,
  SAFE_CAST(revenue AS FLOAT64) AS revenue,
  SAFE_CAST(cost_of_goods_sold AS FLOAT64) AS cost_of_goods_sold,
  SAFE_CAST(gross_profit AS FLOAT64) AS gross_profit,
  SAFE_CAST(unrealized_sales_gain_loss AS FLOAT64) AS unrealized_sales_gain_loss,
  SAFE_CAST(realized_sales_gain_loss AS FLOAT64) AS realized_sales_gain_loss,
  SAFE_CAST(gross_profit_net AS FLOAT64) AS gross_profit_net,
  SAFE_CAST(operating_expenses AS FLOAT64) AS operating_expenses,
  SAFE_CAST(other_income_expense_net AS FLOAT64) AS other_income_expense_net,
  SAFE_CAST(operating_income AS FLOAT64) AS operating_income,
  SAFE_CAST(non_operating_income_expense AS FLOAT64) AS non_operating_income_expense,
  SAFE_CAST(income_before_tax AS FLOAT64) AS income_before_tax,
  SAFE_CAST(income_tax_expense AS FLOAT64) AS income_tax_expense,
  SAFE_CAST(net_income AS FLOAT64) AS net_income,
  SAFE_CAST(eps AS FLOAT64) AS eps
FROM raw_ranked
WHERE row_num = 1