
    
    

select
    id as unique_field,
    count(*) as n_records

from "stockpulse"."public"."ingestion_sale_record"
where id is not null
group by id
having count(*) > 1


