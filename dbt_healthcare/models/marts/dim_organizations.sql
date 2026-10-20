with orgs as (select * from {{ ref('stg_organizations') }})
select organization_id, organization_name, city, state, zip
from orgs