"""Generate the TPC-H sample dataset inside tpch.duckdb.

Usage (from the p01-tpch-foundations folder):
    uv run python scripts/load_tpch.py           # load once; skip if already loaded
    uv run python scripts/load_tpch.py --force   # drop and regenerate

Uses DuckDB's built-in `tpch` extension. Scale factor 0.1 (~100 MB) keeps it
laptop-friendly; the series uses sf=1 (~1 GB).
"""

import argparse
from pathlib import Path

import duckdb

DB_PATH = Path(__file__).resolve().parent.parent / "tpch.duckdb"
SCALE_FACTOR = 0.1
TABLES = ["orders", "lineitem", "customer", "supplier", "part", "partsupp", "nation", "region"]


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

    for table in TABLES:
        count = con.execute(f"select count(*) from main.{table}").fetchone()[0]
        print(f"  {table:<10} {count:>10,} rows")

    con.close()


if __name__ == "__main__":
    main()
