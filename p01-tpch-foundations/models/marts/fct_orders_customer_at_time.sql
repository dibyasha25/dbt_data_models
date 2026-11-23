-- Written by Claude.
-- One row per order (150,000), with the customer's market segment AS IT WAS on the
-- order date, next to their current segment.
--
-- Point-in-time join: the snapshot version that was valid on the order date is the
-- one that started on or before it and either ended after it or hasn't ended yet:
--   dbt_valid_from <= order_date and (dbt_valid_to > order_date or dbt_valid_to is null)
-- valid_to is exclusive (> not >=), so an order placed on the day of a change gets the
-- new version and never matches two.
-- Left join: an order with no matching version keeps its row with a null segment,
-- which the not_null test then reports instead of the order silently disappearing.

with

orders as (

    select * from {{ ref('stg_tpch__orders') }}

),

customer_versions as (

    select
        c_custkey      as customer_id,
        c_mktsegment   as market_segment,
        dbt_valid_from,
        dbt_valid_to

    from {{ ref('customers_snapshot') }}

),

current_customers as (

    select customer_id, market_segment
    from customer_versions
    where dbt_valid_to is null

),

joined as (

    select
        orders.order_id,
        orders.order_date,
        orders.customer_id,
        orders.total_price,
        version_at_order.market_segment  as market_segment_at_order,
        version_at_order.dbt_valid_from  as customer_version_valid_from,
        current_customers.market_segment as current_market_segment

    from orders
    left join customer_versions as version_at_order
        on  orders.customer_id = version_at_order.customer_id
        and version_at_order.dbt_valid_from <= cast(orders.order_date as timestamp)
        and (
            version_at_order.dbt_valid_to > cast(orders.order_date as timestamp)
            or version_at_order.dbt_valid_to is null
        )
    left join current_customers
        on orders.customer_id = current_customers.customer_id

)

select * from joined
