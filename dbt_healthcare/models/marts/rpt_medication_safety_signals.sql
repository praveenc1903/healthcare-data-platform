-- rpt_medication_safety_signals
-- Grain: one row per medication prescribed in the Synthea population.
-- Purpose: show how many openFDA adverse event reports mention each prescribed drug.
-- Join key: RxNorm code (Synthea medication_code = openFDA rxcui).

with synthea_meds as (
    -- Medications prescribed to Synthea patients, aggregated per drug
    select
        medication_code::string       as rxcui,
        medication_description,
        count(*)                      as prescriptions,
        count(distinct patient_id)    as patients
    from {{ ref('fct_medications') }}
    group by 1, 2
),

fda_drug_codes as (
    -- One row per (report, RxNorm code), suspect drugs only
    select distinct
        d.report_id,
        r.value::string as rxcui
    from {{ ref('stg_openfda_event_drugs') }} d,
    lateral flatten(input => d.rxcui_list) r
    where d.drug_role_code = 1        -- 1 = suspect (the drug thought to have caused the reaction)
),

fda_by_code as (
    -- Count reports per RxNorm code, and how many were serious
    select
        c.rxcui,
        count(distinct c.report_id)                                   as adverse_event_reports,
        count(distinct case when e.is_serious then c.report_id end)  as serious_reports
    from fda_drug_codes c
    join {{ ref('stg_openfda_adverse_events') }} e
      on c.report_id = e.report_id
    group by 1
)

select
    m.rxcui,
    m.medication_description,
    m.prescriptions,
    m.patients,
    coalesce(f.adverse_event_reports, 0)   as adverse_event_reports,  -- 0 = no FDA reports in current sample
    coalesce(f.serious_reports, 0)         as serious_reports
from synthea_meds m
left join fda_by_code f                                               -- keep every Synthea medication
  on m.rxcui = f.rxcui