-- models/marts/fct_monthly_revenue.sql
-- Monthly revenue by market segment, excluding pending orders.

with orders_customers as (
    select * from {{ ref('int_orders_customers') }}
),

aggregated as (
    select
        cast(date_trunc('month', order_date) as date) as order_month,
        market_segment,
        count(distinct order_id)         as order_count,
        sum(total_price)                 as total_revenue
    from orders_customers
    where order_status != 'P'            -- business rule: pending orders aren't revenue yet
    group by 1, 2
)

select * from aggregated
