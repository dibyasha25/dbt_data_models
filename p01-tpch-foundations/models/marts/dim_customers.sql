-- Grain: one row per customer (15,000 rows), matching stg_tpch__customers.
-- Customers who never placed an order (5,000) still appear: dropping them would
-- silently change the business question from "who are our customers" to
-- "who are our ordering customers."
--   order_count, lifetime_revenue    -> 0 (a known zero, so sums and averages include them)
--   first_order_date, last_order_date -> null (there is no such date)
--
-- revenue_rank_in_region uses rank(), not row_number(): customers with no orders all
-- have 0 revenue, so they tie and share the last rank in their region (e.g. 1,990 in
-- Asia) instead of getting arbitrary distinct positions.
--
-- Three models:
--   1. stg_tpch__customers   -> customer_id, customer_name, nation_id (the grain)
--   2. int_orders_customers  -> order-level revenue/dates, aggregated up to customer
--   3. stg_tpch__nation      -> region_name, via customer's nation_id

with

customers as (

    select * from {{ ref('stg_tpch__customers') }}

),

orders_customers as (

    select * from {{ ref('int_orders_customers') }}

),

nation as (

    select * from {{ ref('stg_tpch__nation') }}

),
customer_orders as (

    select
        customer_id,
        min(order_date)            as first_order_date,
        max(order_date)            as last_order_date,
        count(distinct order_id)   as order_count,
        sum(total_price)           as lifetime_revenue
    from orders_customers
    group by customer_id

),

final as (
    select
        customers.customer_id,
        customers.customer_name,
        nation.region_name,
        customer_orders.first_order_date,
        customer_orders.last_order_date,
        coalesce(customer_orders.order_count, 0)      as order_count,
        coalesce(customer_orders.lifetime_revenue, 0) as lifetime_revenue,
        rank() over (partition by region_name order by lifetime_revenue desc) as revenue_rank_in_region
    from customers
    LEFT join customer_orders on customers.customer_id = customer_orders.customer_id
    LEFT join nation on customers.nation_id = nation.nation_id
)

select * from final