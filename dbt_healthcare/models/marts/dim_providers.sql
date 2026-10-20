with providers as (select * from {{ ref('stg_providers') }})
select provider_id, provider_name, provider_gender, speciality, city, state
from providers