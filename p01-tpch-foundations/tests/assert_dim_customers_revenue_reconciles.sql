-- dim_customers.lifetime_revenue must add up to the total value of all orders
-- ($21,356,596,030.63 at sf=0.1). If it's higher, a join fanned out and counted orders
-- twice; if it's lower, orders were lost (for example an inner join or a filter).
-- Compared against stg_tpch__orders rather than a hard-coded number, so the test
-- still holds if the data is regenerated at a different scale factor.
-- Returns a row (= fails) only when the two totals differ.

with

dim_total as (

    select sum(lifetime_revenue) as total from {{ ref('dim_customers') }}

),

orders_total as (

    select sum(total_price) as total from {{ ref('stg_tpch__orders') }}

)

select
    dim_total.total    as dim_customers_total,
    orders_total.total as orders_total
from dim_total
cross join orders_total
where dim_total.total <> orders_total.total
