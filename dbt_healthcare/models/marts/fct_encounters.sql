with encounters as (
    select * from {{ ref('stg_encounters') }}
),

patients as (
    select patient_id from {{ ref('dim_patients') }}
),

providers as (
    select provider_id from {{ ref('dim_providers') }}
),

organizations as (
    select organization_id from {{ ref('dim_organizations') }}
)

select
    e.encounter_id,
    e.patient_id,
    e.provider_id,
    e.organization_id,
    e.encounter_start,
    e.encounter_stop,
    datediff('minute', e.encounter_start, e.encounter_stop) as duration_minutes,
    e.encounter_class,
    e.encounter_description,
    e.base_cost,
    e.total_cost,
    e.payer_coverage,
    (e.total_cost - e.payer_coverage) as patient_paid
from encounters e
inner join patients p      on e.patient_id = p.patient_id
left join providers pr     on e.provider_id = pr.provider_id
left join organizations o  on e.organization_id = o.organization_id