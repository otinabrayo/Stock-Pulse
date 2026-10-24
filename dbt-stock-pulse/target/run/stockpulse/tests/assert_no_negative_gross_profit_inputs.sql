
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  select *
from "stockpulse"."analytics_staging"."stg_sales"
where quantity <= 0
   or unit_price < 0
   or unit_cost < 0
  
  
      
    ) dbt_internal_test