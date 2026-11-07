-- =====================================================================
-- Synthea ingestion: Snowflake setup
-- Project: healthcare-data-platform
--
-- Flow:  Synthea CSVs in S3 (raw/synthea/) -> external stage
--        -> INFER_SCHEMA creates each table -> COPY INTO healthcare.raw
--
-- Safe to rerun: objects use IF NOT EXISTS, and COPY INTO skips files it
-- has already loaded (load history is kept for 64 days).
-- Run one statement at a time (Ctrl+Enter), not the whole file.
--
-- Credentials never go in this file. dbt connects with an RSA key pair.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 0. Session context
-- ---------------------------------------------------------------------
use role accountadmin;
use warehouse healthcare_wh;
use database healthcare;
use schema healthcare.raw;


-- ---------------------------------------------------------------------
-- 1. Storage integration (already created)
--    healthcare_s3_int lets Snowflake read the Synthea bucket by assuming
--    an IAM role. This bucket (us-east-1) is managed outside Terraform;
--    the openFDA bucket uses a separate integration (s3_openfda_int).
--    Check its settings with:
-- ---------------------------------------------------------------------
desc integration healthcare_s3_int;


-- ---------------------------------------------------------------------
-- 2. File formats
--    csv_format        : skips the header row (plain loads)
--    csv_format_header : reads the header row as column names. Required
--                        by INFER_SCHEMA and MATCH_BY_COLUMN_NAME.
-- ---------------------------------------------------------------------
create file format if not exists healthcare.raw.csv_format
  type = 'CSV'
  field_delimiter = ','
  skip_header = 1
  field_optionally_enclosed_by = '"'
  null_if = ('', 'NULL')
  empty_field_as_null = true;

create file format if not exists healthcare.raw.csv_format_header
  type = 'CSV'
  field_delimiter = ','
  parse_header = true
  field_optionally_enclosed_by = '"'
  null_if = ('', 'NULL')
  empty_field_as_null = true;


-- ---------------------------------------------------------------------
-- 3. External stage
--    Named pointer to the Synthea folder in S3. Stores no data.
-- ---------------------------------------------------------------------
create stage if not exists healthcare.raw.synthea_stage
  storage_integration = healthcare_s3_int
  url = 's3://healthcare-data-platform-raw-us-east-1/raw/synthea/'
  file_format = healthcare.raw.csv_format;

-- Connection test: should list the 7 CSV files.
list @healthcare.raw.synthea_stage;


-- ---------------------------------------------------------------------
-- 4. Create tables from the CSV headers, then load them
--
--    INFER_SCHEMA reads each CSV's header and data types, and
--    USING TEMPLATE builds the table from that, so no column list is
--    typed by hand. ORDER BY ORDER_ID keeps the CSV's column order.
--
--    MATCH_BY_COLUMN_NAME loads each CSV column into the table column
--    with the same name, regardless of position.
-- ---------------------------------------------------------------------

-- PATIENTS
create table if not exists healthcare.raw.patients
  using template (
    select array_agg(object_construct(*)) within group (order by order_id)
    from table(infer_schema(
      location    => '@healthcare.raw.synthea_stage/patients.csv',
      file_format => 'healthcare.raw.csv_format_header'))
  );

copy into healthcare.raw.patients
  from '@healthcare.raw.synthea_stage/patients.csv'
  file_format = (format_name = 'healthcare.raw.csv_format_header')
  match_by_column_name = case_insensitive;


-- ENCOUNTERS
create table if not exists healthcare.raw.encounters
  using template (
    select array_agg(object_construct(*)) within group (order by order_id)
    from table(infer_schema(
      location    => '@healthcare.raw.synthea_stage/encounters.csv',
      file_format => 'healthcare.raw.csv_format_header'))
  );

copy into healthcare.raw.encounters
  from '@healthcare.raw.synthea_stage/encounters.csv'
  file_format = (format_name = 'healthcare.raw.csv_format_header')
  match_by_column_name = case_insensitive;


-- CONDITIONS
create table if not exists healthcare.raw.conditions
  using template (
    select array_agg(object_construct(*)) within group (order by order_id)
    from table(infer_schema(
      location    => '@healthcare.raw.synthea_stage/conditions.csv',
      file_format => 'healthcare.raw.csv_format_header'))
  );

copy into healthcare.raw.conditions
  from '@healthcare.raw.synthea_stage/conditions.csv'
  file_format = (format_name = 'healthcare.raw.csv_format_header')
  match_by_column_name = case_insensitive;


-- MEDICATIONS
create table if not exists healthcare.raw.medications
  using template (
    select array_agg(object_construct(*)) within group (order by order_id)
    from table(infer_schema(
      location    => '@healthcare.raw.synthea_stage/medications.csv',
      file_format => 'healthcare.raw.csv_format_header'))
  );

copy into healthcare.raw.medications
  from '@healthcare.raw.synthea_stage/medications.csv'
  file_format = (format_name = 'healthcare.raw.csv_format_header')
  match_by_column_name = case_insensitive;


-- PROCEDURES
create table if not exists healthcare.raw.procedures
  using template (
    select array_agg(object_construct(*)) within group (order by order_id)
    from table(infer_schema(
      location    => '@healthcare.raw.synthea_stage/procedures.csv',
      file_format => 'healthcare.raw.csv_format_header'))
  );

copy into healthcare.raw.procedures
  from '@healthcare.raw.synthea_stage/procedures.csv'
  file_format = (format_name = 'healthcare.raw.csv_format_header')
  match_by_column_name = case_insensitive;


-- PROVIDERS
create table if not exists healthcare.raw.providers
  using template (
    select array_agg(object_construct(*)) within group (order by order_id)
    from table(infer_schema(
      location    => '@healthcare.raw.synthea_stage/providers.csv',
      file_format => 'healthcare.raw.csv_format_header'))
  );

copy into healthcare.raw.providers
  from '@healthcare.raw.synthea_stage/providers.csv'
  file_format = (format_name = 'healthcare.raw.csv_format_header')
  match_by_column_name = case_insensitive;


-- ORGANIZATIONS
create table if not exists healthcare.raw.organizations
  using template (
    select array_agg(object_construct(*)) within group (order by order_id)
    from table(infer_schema(
      location    => '@healthcare.raw.synthea_stage/organizations.csv',
      file_format => 'healthcare.raw.csv_format_header'))
  );

copy into healthcare.raw.organizations
  from '@healthcare.raw.synthea_stage/organizations.csv'
  file_format = (format_name = 'healthcare.raw.csv_format_header')
  match_by_column_name = case_insensitive;


-- ---------------------------------------------------------------------
-- 5. Verify the load: row count per table
-- ---------------------------------------------------------------------
select 'patients' as table_name, count(*) as row_count from healthcare.raw.patients
union all select 'encounters',    count(*) from healthcare.raw.encounters
union all select 'conditions',    count(*) from healthcare.raw.conditions
union all select 'medications',   count(*) from healthcare.raw.medications
union all select 'procedures',    count(*) from healthcare.raw.procedures
union all select 'providers',     count(*) from healthcare.raw.providers
union all select 'organizations', count(*) from healthcare.raw.organizations;

-- Inspect the columns INFER_SCHEMA created for a table
describe table healthcare.raw.patients;


-- ---------------------------------------------------------------------
-- 6. Full reload (only when the CSVs in S3 have been regenerated)
--    TRUNCATE empties the table but keeps its structure. FORCE = TRUE
--    makes COPY load the file even though it was loaded before.
--    Example for one table; repeat for the others as needed.
--
--    Avoid CREATE OR REPLACE TABLE for this: it drops the table, and any
--    rerun of the script would wipe loaded data.
-- ---------------------------------------------------------------------
truncate table healthcare.raw.patients;

copy into healthcare.raw.patients
  from '@healthcare.raw.synthea_stage/patients.csv'
  file_format = (format_name = 'healthcare.raw.csv_format_header')
  match_by_column_name = case_insensitive
  force = true;
