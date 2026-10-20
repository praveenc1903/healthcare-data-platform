with source as (
    select * from {{ source ('raw', 'medications')}}
)

select 
    "PATIENT" as patient_id,
    "ENCOUNTER" as encounter_id,
    "START" as medication_start,
    "STOP" as medication_stop,
    "CODE" as medication_code,
    "DESCRIPTION" as medication_description,
    "BASE_COST" as base_cost,
    "TOTALCOST" as total_cost
from source