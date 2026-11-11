# dbt Analytics Engineering

A hands-on dbt learning portfolio built on DuckDB. Each folder is its own dbt project with its own README.

| # | Project | Focus | Status |
|---|---------|-------|--------|
| P01 | [TPC-H Foundations](p01-tpch-foundations/) | sources, staging/intermediate/marts, tests, docs, seeds, snapshots, macros, materializations | Built; extensions in progress |
| P02 | Campaign Performance Mart | star schema, grain, window functions in marts (synthetic data) | Planned |
| P03 | Advertiser History | incremental models, timestamp snapshots, unit tests | Planned |
| P04 | Traffic Quality Signature | custom macros, custom generic tests (synthetic data) | Planned |
| P05 | CI + Databricks | GitHub Actions running `dbt build` on PRs, dbt-databricks, dashboard | Planned |

**Stack:** dbt-core · DuckDB (P01–P04) · Databricks (P05) · uv · GitHub PRs with small commits
