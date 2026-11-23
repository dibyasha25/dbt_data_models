"""Generate the TPC-H sample dataset inside tpch.duckdb.

Usage (from the p01-tpch-foundations folder):
    uv run python scripts/load_tpch.py           # load once; skip if already loaded
    uv run python scripts/load_tpch.py --force   # drop and regenerate

Uses DuckDB's built-in `tpch` extension. Scale factor 0.1 (~100 MB) keeps it
laptop-friendly; the series uses sf=1 (~1 GB).

TPC-H has no "last updated" column, so this script adds one to `customer`:
c_updated_at = 1992-01-01 (the first TPC-H order date) for every row. The snapshot
uses it with the `timestamp` strategy, so customer history lines up with the order
dates (1992-1998) for the point-in-time join. (Written by Claude.)
"""

import argparse
from pathlib import Path

import duckdb

DB_PATH = Path(__file__).resolve().parent.parent / "tpch.duckdb"
SCALE_FACTOR = 0.1
TABLES = ["orders", "lineitem", "customer", "supplier", "part", "partsupp", "nation", "region"]
INITIAL_UPDATED_AT = "1992-01-01 00:00:00"


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--force", action="store_true", help="drop existing TPC-H tables and regenerate")
    args = parser.parse_args()

    con = duckdb.connect(str(DB_PATH))
    con.execute("INSTALL tpch")
    con.execute("LOAD tpch")

    existing = {
        row[0]
        for row in con.execute(
            "select table_name from information_schema.tables where table_schema = 'main'"
        ).fetchall()
    }

    if set(TABLES) <= existing and not args.force:
        print(f"TPC-H already loaded in {DB_PATH.name}; use --force to regenerate.")
    else:
        for table in TABLES:
            con.execute(f"drop table if exists main.{table}")
        con.execute(f"CALL dbgen(sf={SCALE_FACTOR})")
        print(f"Generated TPC-H sf={SCALE_FACTOR} in {DB_PATH.name}")

    customer_cols = {
        row[0]
        for row in con.execute(
            "select column_name from information_schema.columns "
            "where table_schema = 'main' and table_name = 'customer'"
        ).fetchall()
    }
    if "c_updated_at" not in customer_cols:
        con.execute("alter table main.customer add column c_updated_at timestamp")
        con.execute("update main.customer set c_updated_at = ?", [INITIAL_UPDATED_AT])
        print(f"Added customer.c_updated_at = {INITIAL_UPDATED_AT}")

    for table in TABLES:
        count = con.execute(f"select count(*) from main.{table}").fetchone()[0]
        print(f"  {table:<10} {count:>10,} rows")

    con.close()


if __name__ == "__main__":
    main()
