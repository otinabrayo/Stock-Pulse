
  
    

  create  table "stockpulse"."analytics_marts"."fct_daily_sales__dbt_tmp"
  
  
    as
  
  (
    with sales as (
    select *
    from "stockpulse"."analytics_staging"."stg_unified_sales"

),

daily_aggregates as (

    select
        cast(sold_at as date) as sale_date,
        count(*) as sales_lines,
        count(distinct transaction_id) as transactions,
        sum(quantity) as units_sold,
        sum(quantity * unit_price) as revenue,
        sum(quantity * unit_cost) as cost_of_goods_sold
    from sales
    group by cast(sold_at as date)

)

select
    sale_date,
    sales_lines,
    transactions,
    units_sold,
    revenue,
    cost_of_goods_sold,
    revenue - cost_of_goods_sold as gross_profit,
    case
        when revenue = 0 then null
        else (revenue - cost_of_goods_sold) / revenue
    end as gross_margin_rate
from daily_aggregates
  );
  