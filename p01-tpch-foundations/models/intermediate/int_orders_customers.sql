-- One row per order, enriched with customer attributes.
-- Left join: every order survives even if its customer is missing.
--
-- Materialization: view (folder default). Tried ephemeral in Part 8 and went back:
-- two marts read this model (dim_customers will make three), so ephemeral would paste
-- the join into each of them, and a view can be queried directly when debugging.

with

orders as (

    select * from {{ ref('stg_tpch__orders') }}

),

customers as (

    select * from {{ ref('stg_tpch__customers') }}

),

joined as (

    select
        orders.order_id,
        orders.order_date,
        orders.order_status,
        orders.total_price,
        orders.customer_id,
        customers.customer_name,
        customers.market_segment

    from orders
    left join customers
        on orders.customer_id = customers.customer_id

)

select * from joined
