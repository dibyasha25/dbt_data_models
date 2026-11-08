-- Business rule: an order cannot be placed in the future.
-- A singular test passes when this query returns 0 rows;
-- every row returned is an offending order.

select
    order_id,
    order_date
from {{ ref('stg_tpch__orders') }}
where order_date > current_date
