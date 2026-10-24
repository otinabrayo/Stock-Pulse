select *
from "stockpulse"."analytics_staging"."stg_sales"
where quantity <= 0
   or unit_price < 0
   or unit_cost < 0