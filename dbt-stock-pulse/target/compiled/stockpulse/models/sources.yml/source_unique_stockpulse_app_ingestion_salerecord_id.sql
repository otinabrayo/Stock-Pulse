
    
    

select
    id as unique_field,
    count(*) as n_records

from "stockpulse"."public"."ingestion_salerecord"
where id is not null
group by id
having count(*) > 1


