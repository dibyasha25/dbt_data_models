-- One row per customer who has placed at least one order:
-- lifetime booked order value (all statuses) and number of orders.

with orders_customers as (

    select * from {{ ref('int_orders_customers') }}

),

aggregated as (

    select
        customer_id,
        customer_name,
        sum(total_price)          as total_order_value,
        count(distinct order_id)  as order_count

    from orders_customers
    group by 1, 2

)

select * from aggregated
