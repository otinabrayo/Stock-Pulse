
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select sales_lines
from "stockpulse"."analytics_marts"."fct-daily-sales"
where sales_lines is null



  
  
      
    ) dbt_internal_test