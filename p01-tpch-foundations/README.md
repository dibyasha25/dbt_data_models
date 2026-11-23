# P01 · TPC-H Foundations

A dbt project on DuckDB that turns the TPC-H benchmark data into tested, documented models, from raw tables through staging and intermediate layers to marts. It follows a public dbt + DuckDB tutorial series, adapted to one consistent naming convention, with a few tutorial bugs found and fixed along the way.

**Stack:** dbt-core 1.12 · dbt-duckdb 1.11 · dbt_utils 1.4 · DuckDB · uv
**Data:** TPC-H at scale factor 0.1 (150,000 orders, 600,572 order lines, 15,000 customers), generated locally

## Business questions

1. **How does booked order value move month by month, by customer market segment?** → `fct_monthly_revenue`
2. **Who are the highest-value customers?** → `fct_order_revenue`
3. **Who is each customer, and how do they rank by revenue in their region?** → `dim_customers`
4. **What segment was the customer in when they placed each order?** → `customers_snapshot` + `fct_orders_customer_at_time` (point-in-time join), and `analyses/customer_as_of.sql` for any single moment

## Approach

```
sources (tpch_raw) ─┐
seeds (lookups) ────┴─► staging (views) ─► intermediate (view) ─► marts (tables)
                                                    snapshot (SCD2 on raw customers) ─► point-in-time mart
```

| Layer | Models | Rule |
|---|---|---|
| **Staging** (view) | `stg_tpch__orders`, `__customers`, `__nation`, `__region`, `__lineitem` | One source each. Rename and type only; no filters. The only joins are small seed lookups. |
| **Intermediate** (view) | `int_orders_customers` | Orders left-joined to customers, so every order survives (150,000 in = 150,000 out). |
| **Marts** (table) | `fct_monthly_revenue`, `fct_order_revenue`, `dim_customers`, `fct_orders_customer_at_time` | Aggregations and point-in-time facts for people and BI. |
| **Seeds** | `region_codes`, `order_priority` | Small, project-owned lookups versioned in git and referenced with `ref()` so they show in the lineage. |
| **Snapshot** | `customers_snapshot` | SCD Type 2 history of the **raw** customer table, `timestamp` strategy on `c_updated_at` (added by the load script, since TPC-H has none). |

Materializations are set per folder in `dbt_project.yml`, each with a one-line reason. `int_orders_customers` was tried as `ephemeral` and kept as a view: several marts read it, and a view can be queried directly when debugging.

**Grain of each mart**
- `fct_monthly_revenue`: one row per (month, market segment), 400 rows
- `fct_order_revenue`: one row per customer **who has ordered**, 10,000 rows (TPC-H gives one in three customers no orders)
- `dim_customers`: one row per customer, **all 15,000**. The 5,000 with no orders get `order_count` and `lifetime_revenue` = 0 and null order dates, and tie at the bottom of `revenue_rank_in_region` (`rank()` partitioned by region)
- `fct_orders_customer_at_time`: one row per order, 150,000 rows, each with the segment valid on the order date

`region_name` comes from the `region_codes` seed via `stg_tpch__nation`. That seed is a learning exercise in seeds: TPC-H already has a `region` table with the same names.

![Lineage](docs/lineage_final.png)

## Tests

`dbt build` → **PASS=65, WARN=0, ERROR=0** (2 seeds, 1 snapshot, 10 models, 52 tests)

| Test | Count | Guards against |
|---|---|---|
| `not_null` | 34 | missing keys and measures; null lookups after a left join |
| `unique` | 10 | duplicate rows on every primary key, including the `line_item_id` surrogate key |
| `relationships` | 3 | orders without a customer, lines without an order, priority codes missing from the seed |
| `accepted_values` | 1 | unexpected `order_status` values (severity **warn**: a quality signal, not a reason to stop) |
| `assert_order_date_not_in_future` | 1 | orders dated in the future |
| `assert_lineitem_price_not_rescaled` | 1 | someone applying a cents-to-dollars conversion to prices that are already dollars |
| `assert_dim_customers_revenue_reconciles` | 1 | `dim_customers` revenue not adding up to all orders ($21,356,596,030.63): a join fan-out or lost orders |
| `assert_order_total_price_not_negative` | 1 | negative order totals (sign flips, refunds mixed into orders) |

Every column has a description that says what it holds and what a downstream user needs to know (units, inclusions, exclusions).

## Traps found while following the tutorial

1. **A status code was mislabelled, and it skewed a revenue metric.** The tutorial treats `order_status = 'P'` as *pending* and filters it out of revenue. Writing the column description showed that in TPC-H, **P = partially shipped** (F = fully shipped, O = open). Status is a function of order date: up to 1994 every order is F, from 1996 every order is O, and every P order is in 1995. The filter wasn't removing a category, it was cutting a hole in mid-1995 (April 1995: 572 orders instead of 1,880). **Fix:** no status filter; the measure is called `total_order_value` (booked order value, all statuses).

2. **A macro would have cut revenue 100× with no error.** The tutorial applies `cents_to_dollars` to `l_extendedprice`. TPC-H prices are already dollars (`DECIMAL(15,2)`, 901.00 to 95,949.50). Applied on purpose to check: the build passed and total line value fell from **$21.6B to $216M**. **Fix:** the macro is kept for learning but not applied, and `assert_lineitem_price_not_rescaled` fails on all 600,572 lines if it ever is.

3. **The point-in-time snapshot query returned nothing.** The tutorial filters `dbt_valid_from >= start and dbt_valid_to <= end`. Current versions have `dbt_valid_to = NULL`, which fails every comparison, so it returned **0 rows**. **Fix:** `dbt_valid_from <= as_of and (dbt_valid_to > as_of or dbt_valid_to is null)`, verified before, between and after two snapshot runs.

4. **The snapshot history couldn't be joined to orders at all.** With the `check` strategy, each version's `dbt_valid_from` is the time `dbt snapshot` ran (Nov 2026), but TPC-H orders are dated 1992–1998, so a point-in-time join by order date matched **zero** versions. **Fix:** the load script adds `c_updated_at` (1992-01-01 for everyone), the simulated changes are dated inside 1992–1998, and the snapshot uses the `timestamp` strategy, which takes `dbt_valid_from` from `c_updated_at`. Customer 1 moved from BUILDING to HOUSEHOLD on 1995-01-01: their 4 earlier orders show BUILDING, the 5 later ones HOUSEHOLD.

5. **Inconsistent names across the series** (`stg_orders` vs `stg_tpch__orders`, `order_key` vs `order_id`). This project uses one convention: `stg_tpch__<table>`, snake_case `*_id` columns. `strip_prefix` gives `orderkey` and `extendedprice`, so it's only used where the stripped name is already right.

6. **Seed CSV values with leading spaces.** The tutorial's CSV has spaces after commas (`1, America`), which stores `' America'` and silently breaks joins. The seeds here have none, and their column types are pinned.

**Also learned the hard way**
- Switching a model to `ephemeral` doesn't drop its old view. The stale view kept answering queries until dropped by hand.
- While on the `check` strategy, the snapshot only watched its `check_cols`: a phone change was missed. A change made and reverted between two runs leaves no trace under either strategy. The `timestamp` strategy catches any column, but only if the source bumps `updated_at`.
- A null is not a zero: `count_if(order_count = 0)` returned 0 while 5,000 customers had a null count, because `null = 0` is unknown, not true.
- DuckDB / dbt-duckdb have no `materialized_view`; marts stay tables.

## How to run

From this folder:

```bash
uv sync                               # install dbt from uv.lock
uv run python scripts/load_tpch.py    # generate TPC-H into tpch.duckdb (git-ignored)
uv run dbt deps                       # install dbt_utils from package-lock.yml
uv run dbt build                      # seeds, snapshot, models and tests, in DAG order
```

`profiles.yml` lives in this folder (not `~/.dbt/`) with a relative DuckDB path, so a fresh clone and CI work without setup. DuckDB has no credentials, so nothing secret is stored. Run dbt commands from this folder, or dbt looks for `~/.dbt/` and fails.

Optional:
```bash
uv run python scripts/simulate_customer_changes.py   # change 4 raw customers, dated 1995-1998, then:
uv run dbt build                                      # snapshot their history and rebuild the point-in-time mart
uv run dbt compile --select customer_as_of --vars "{as_of: '1996-06-01'}"
uv run dbt docs generate && uv run dbt docs serve     # lineage and column docs
```

## Who wrote what

Built with Claude Code as a pair. I wrote `dim_customers` (including the window function) myself, from hints. Claude wrote the timestamp-snapshot redesign, `fct_orders_customer_at_time`, and the `dim_customers` and negative-price tests; those are marked "Written by Claude" in the code and commit messages.

## What I learned

- **Documenting a column is how you find out what it means.** The status-code bug only surfaced while writing a description.
- **State the grain of every model.** "One row per customer" vs "one row per customer who has ordered" is a 5,000-row difference.
- **A build that passes can still be wrong.** The cents conversion and the snapshot query both ran without errors; tests and reconciliation counts caught them.
- **Don't paste tutorial code as-is.** Check it against the project's names, the data's units and the logic first.
