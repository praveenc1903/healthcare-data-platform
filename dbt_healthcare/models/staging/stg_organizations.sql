with source as (select * from {{ source('raw', 'organizations') }})
select
    "Id" as organization_id,
    "NAME" as organization_name,
    "CITY" as city,
    "STATE" as state,
    "ZIP" as zip
from source