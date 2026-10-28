
with sales as (
    select *
    from {{ ref('stg_unified_sales') }}
),

products as (
    select *
    from {{ ref('stg_products') }}
),

product_lookup as (
    select
        sku,
        max(product_name) as product_name,
        max(category) as category
    from products
    group by sku
),

sales_with_products as (
    select
        sales.transaction_id,
        sales.sku,
        sales.quantity,
        sales.unit_price,
        sales.unit_cost,
        coalesce(
            products_by_id.product_name,
            products_by_sku.product_name,
            sales.sku
        ) as product_name,
        coalesce(
            products_by_id.category,
            products_by_sku.category,
            'Uncategorised'
        ) as category
    from sales
    left join products as products_by_id
        on sales.product_id = products_by_id.product_id
    left join product_lookup as products_by_sku
        on sales.sku = products_by_sku.sku
),

product_aggregates as (
    select
        sku,
        max(product_name) as product_name,
        max(category) as category,
        sum(quantity) as units_sold,
        count(*) as sales_lines,
        count(distinct transaction_id) as transactions,
        sum(quantity * unit_price) as revenue,
        sum(quantity * unit_cost) as cost_of_goods_sold
    from sales_with_products
    group by sku
)

select
    sku,
    product_name,
    category,
    units_sold,
    sales_lines,
    transactions,
    revenue,
    cost_of_goods_sold,
    revenue - cost_of_goods_sold as gross_profit
from product_aggregates
