-- One row per order line, renamed from raw TPC-H `lineitem`.
-- Natural key is (order_id, line_number); line_item_id is a surrogate key over it.
--
-- Renaming strategy:
--   - Keys and multi-word columns are renamed explicitly, because strip_prefix
--     would give 'orderkey' / 'extendedprice' instead of this project's
--     snake_case names ('order_id' / 'extended_price').
--   - Single-word columns go through the strip_prefix macro in a Jinja loop,
--     where the stripped name is already the name we want.
--   - Prices are already in dollars: cents_to_dollars is deliberately NOT used.

{%- set simple_columns = ['l_quantity', 'l_discount', 'l_tax'] %}

with

source as (

    select * from {{ source('tpch_raw', 'lineitem') }}

),

renamed as (

    select
        {{ dbt_utils.generate_surrogate_key(['l_orderkey', 'l_linenumber']) }} as line_item_id,
        l_orderkey      as order_id,
        l_linenumber    as line_number,
        l_partkey       as part_id,
        l_suppkey       as supplier_id,
        l_extendedprice as extended_price,
        l_returnflag    as return_flag,
        l_linestatus    as line_status,
        l_shipdate      as ship_date,
        l_commitdate    as commit_date,
        l_receiptdate   as receipt_date,
        l_shipinstruct  as ship_instructions,
        l_shipmode      as ship_mode,
        l_comment       as line_comment,
        {%- for column in simple_columns %}
        {{ strip_prefix(column, 'l_') }}{{ ',' if not loop.last }}
        {%- endfor %}

    from source

)

select * from renamed
