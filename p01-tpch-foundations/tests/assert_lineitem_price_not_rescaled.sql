-- Guard against the cents_to_dollars trap: TPC-H prices are already in dollars.
-- If anyone applies a conversion (or any rescaling) to extended_price in staging,
-- the staged value stops matching the raw value and this test returns those lines.

select
    stg.line_item_id,
    stg.extended_price as staged_price,
    raw.l_extendedprice as raw_price

from {{ ref('stg_tpch__lineitem') }} as stg
inner join {{ source('tpch_raw', 'lineitem') }} as raw
    on stg.order_id = raw.l_orderkey
   and stg.line_number = raw.l_linenumber

where stg.extended_price != raw.l_extendedprice
