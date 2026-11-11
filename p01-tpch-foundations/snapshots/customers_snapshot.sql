-- SCD Type 2 history of raw TPC-H customers.
-- Snapshots the RAW source, not stg_tpch__customers: if staging logic changes later,
-- the recorded history must not change with it.
-- Strategy 'check': TPC-H has no trustworthy updated_at column, so dbt compares
-- the listed columns between runs and opens a new version when any of them differ.

{% snapshot customers_snapshot %}

{{
    config(
        target_schema='snapshots',
        unique_key='c_custkey',
        strategy='check',
        check_cols=['c_mktsegment', 'c_acctbal', 'c_address'],
    )
}}

select * from {{ source('tpch_raw', 'customer') }}

{% endsnapshot %}
