-- Written by Claude.
-- An order's total_price (after discount, including tax) can never be negative.
-- A negative value would mean a sign flip, a bad discount, or a refund row mixed into
-- orders, and it would quietly reduce every revenue total built on this column.
-- Returns the offending orders (= fails) if any exist.

select
    order_id,
    total_price
from {{ ref('stg_tpch__orders') }}
where total_price < 0
