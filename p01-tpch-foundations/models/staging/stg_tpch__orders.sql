-- One row per order, with a readable priority label and numeric rank
-- from the order_priority seed (left join, so no order is dropped).

with

source as (

    select * from {{ source('tpch_raw', 'orders') }}

),

order_priority as (

    select * from {{ ref('order_priority') }}

),

renamed as (

    select
        o_orderkey      as order_id,
        o_custkey       as customer_id,
        o_orderstatus   as order_status,
        o_totalprice    as total_price,
        o_orderdate     as order_date,
        o_orderpriority as order_priority,
        o_clerk         as clerk,
        o_shippriority  as ship_priority,
        o_comment       as order_comment

    from source

),

enriched as (

    select
        renamed.order_id,
        renamed.customer_id,
        renamed.order_status,
        renamed.total_price,
        renamed.order_date,
        renamed.order_priority,
        order_priority.priority_label,
        order_priority.priority_rank,
        renamed.clerk,
        renamed.ship_priority,
        renamed.order_comment

    from renamed
    left join order_priority
        on renamed.order_priority = order_priority.priority_code

)

select * from enriched
