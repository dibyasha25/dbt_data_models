-- One row per nation, with the region display name from the region_codes seed.
-- The seed join is the one allowed exception to "no joins in staging":
-- a small, project-owned lookup applied once, early. Left join so no nation is lost.

with

source as (

    select * from {{ source('tpch_raw', 'nation') }}

),

region_codes as (

    select * from {{ ref('region_codes') }}

),

renamed as (

    select
        n_nationkey as nation_id,
        n_name      as nation_name,
        n_regionkey as region_id,
        n_comment   as nation_comment

    from source

),

enriched as (

    select
        renamed.nation_id,
        renamed.nation_name,
        renamed.region_id,
        region_codes.region_name,
        renamed.nation_comment

    from renamed
    left join region_codes
        on renamed.region_id = region_codes.region_id

)

select * from enriched
