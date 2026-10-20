with source as (select * from {{ source('raw', 'providers') }})
select
    "Id" as provider_id,
    "ORGANIZATION" as organization_id,
    "NAME" as provider_name,
    "GENDER" as provider_gender,
    "SPECIALITY" as speciality,
    "CITY" as city,
    "STATE" as state
from source