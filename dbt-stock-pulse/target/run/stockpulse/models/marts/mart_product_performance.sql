
  
    

  create  table "stockpulse"."analytics_marts"."mart_product_performance__dbt_tmp"
  
  
    as
  
  (
    with sales as (
    select *
    from "stockpulse"."analytics_staging"."stg_sales"
),

products as (
    select *
    from "stockpulse"."analytics_staging"."stg_products"
),

product_aggregates as (
    select
        sales.sku,
        products.product_name,
        products.category,
        sum(sales.quantity) as units_sold,
        count(*) as sales_lines,
        count(distinct sales.transaction_id) as transactions,
        sum(sales.quantity * sales.unit_price) as revenue,
        sum(sales.quantity * sales.unit_cost) as cost_of_goods_sold
    from sales
    left join products
        on sales.product_id = products.product_id
    group by
        sales.sku,
        products.product_name,
        products.category
)

select
    sku,
    coalesce(product_name, sku) as product_name,
    coalesce(category, 'Uncategorised') as category,
    units_sold,
    sales_lines,
    transactions,
    revenue,
    cost_of_goods_sold,
    revenue - cost_of_goods_sold as gross_profit
from product_aggregates
  );
  