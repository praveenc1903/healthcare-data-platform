-- stg_openfda_adverse_events
-- Grain: one row per openFDA adverse event report (deduplicated).
-- Source: healthcare.raw.openfda_drug_events (one JSON report per row).

with source as (
    -- Bronze table: raw JSON reports loaded from S3 via COPY INTO
    select * from {{ source('raw', 'openfda_drug_events') }}
),

deduped as (
    -- Daily API pulls overlap, so the same report can appear in several files.
    -- Keep only the most recently loaded copy of each report.
    select *
    from source
    qualify row_number() over (
        partition by raw:safetyreportid::string   -- group copies of the same report
        order by loaded_at desc                   -- newest load first
    ) = 1                                         -- keep the newest copy only
),

countries as (
    -- Seed lookup: ISO 2-letter code -> full country name (plus EU)
    select * from {{ ref('country_codes') }}
),

reports as (
    select
        raw:safetyreportid::string                        as report_id,          -- unique report ID
        try_to_date(raw:receivedate::string, 'YYYYMMDD')  as received_date,      -- date FDA received the report
        raw:serious::int = 1                              as is_serious,         -- true if hospitalisation, disability, death, etc.
        raw:patient:patientsex::string                    as patient_sex_code,   -- 0 unknown, 1 male, 2 female
        raw:patient:patientonsetage::float                as patient_age,        -- age at onset (unit varies; see patientonsetageunit)
        raw:primarysource:reportercountry::string         as reporter_country,   -- where the reporter is based (raw code)
        raw:occurcountry::string                          as occur_country,      -- where the event happened (raw code, may be null)
        -- Best available country: where it happened, else where it was reported
        coalesce(
            raw:occurcountry::string,
            raw:primarysource:reportercountry::string
        )                                                 as event_country_code,
        source_file,                                                             -- S3 file the row came from (lineage)
        loaded_at                                                                -- when it was loaded into Snowflake
    from deduped
)

select
    r.report_id,
    r.received_date,
    r.is_serious,
    r.patient_sex_code,
    r.patient_age,
    r.reporter_country,
    r.occur_country,
    coalesce(r.event_country_code, 'XX')                       as event_country_code,  -- 'XX' = no country given
    -- Full name; fall back to the raw code if unmapped, then 'Unknown' if both are missing
    coalesce(c.country_name, r.event_country_code, 'Unknown')  as event_country,
    r.source_file,
    r.loaded_at
from reports r
left join countries c
  on r.event_country_code = c.country_code