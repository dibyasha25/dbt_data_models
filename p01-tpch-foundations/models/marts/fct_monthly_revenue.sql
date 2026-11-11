-- models/marts/fct_monthly_revenue.sql
-- Monthly booked order value by market segment.
-- Booked order value, all statuses. In TPC-H, status is a function of order date,
-- so any status filter distorts the monthly trend.

with orders_customers as (
    select * from {{ ref('int_orders_customers') }}
),

aggregated as (
    select
        cast(date_trunc('month', order_date) as date) as order_month,
        market_segment,
        count(distinct order_id)         as order_count,
        sum(total_price)                 as total_order_value
    from orders_customers
    group by 1, 2
)

select * from aggregated
