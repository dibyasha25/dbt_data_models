-- Point-in-time lookup: what did each customer look like at a given moment?
--
-- A version was true at :as_of if it started on or before :as_of and either
-- ended after :as_of or hasn't ended yet (dbt_valid_to is null = current).
--
-- The tutorial's version (dbt_valid_from >= start and dbt_valid_to <= end) is wrong:
-- it drops current rows (dbt_valid_to is null fails the comparison) and versions
-- that span the boundary.
--
-- Usage:
--   uv run dbt compile --select customer_as_of --vars "{as_of: '2026-11-11 18:40:00'}"
-- then run the compiled SQL from target/compiled/.
-- Without --vars, as_of defaults to a far-future date, which returns each customer's
-- current version (and keeps `dbt compile` / `dbt docs generate` from failing).

{% set as_of = var("as_of", "9999-12-31 00:00:00") %}

select
    c_custkey     as customer_id,
    c_mktsegment  as market_segment,
    c_acctbal     as account_balance,
    c_address     as customer_address,
    dbt_valid_from,
    dbt_valid_to

from {{ ref('customers_snapshot') }}

where dbt_valid_from <= cast('{{ as_of }}' as timestamp)
  and (dbt_valid_to > cast('{{ as_of }}' as timestamp) or dbt_valid_to is null)
