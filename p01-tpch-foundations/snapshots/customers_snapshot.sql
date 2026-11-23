-- SCD Type 2 history of raw TPC-H customers.
-- Snapshots the RAW source, not stg_tpch__customers: if staging logic changes later,
-- the recorded history must not change with it.
--
-- Strategy 'timestamp' (switched from 'check'; written by Claude):
--   - 'check' compared check_cols between runs and stamped each new version with the
--     time `dbt snapshot` ran (Nov 2026), so no 1992-1998 order could ever match a version.
--   - 'timestamp' opens a new version when c_updated_at moves forward, and uses that
--     value as dbt_valid_from, so versions line up with the business timeline.
--   - It catches a change to ANY column (the phone change that 'check' missed), but it
--     trusts the source to bump c_updated_at; an edit without a bump is invisible.
-- c_updated_at is added by scripts/load_tpch.py (TPC-H doesn't have one).

{% snapshot customers_snapshot %}

{{
    config(
        target_schema='snapshots',
        unique_key='c_custkey',
        strategy='timestamp',
        updated_at='c_updated_at',
    )
}}

select * from {{ source('tpch_raw', 'customer') }}

{% endsnapshot %}
