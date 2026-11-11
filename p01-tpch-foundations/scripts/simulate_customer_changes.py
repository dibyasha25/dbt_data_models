"""Simulate changes to raw TPC-H customers so the snapshot has history to record.

TPC-H data never changes on its own. Run this AFTER a first `dbt snapshot`,
then run `dbt snapshot` again and compare.

Usage (from the p01-tpch-foundations folder):
    uv run python scripts/simulate_customer_changes.py

Note: re-running scripts/load_tpch.py --force resets the raw data.
"""

from pathlib import Path

import duckdb

DB_PATH = Path(__file__).resolve().parent.parent / "tpch.duckdb"

# (customer key, column, new value, why it's here)
CHANGES = [
    (1, "c_mktsegment", "HOUSEHOLD", "watched column changes"),
    (2, "c_address", "12 New Street", "watched column changes"),
    (3, "c_acctbal", 0.00, "watched column changes"),
    (4, "c_phone", "99-999-999-9999", "tricky: c_phone is NOT in check_cols"),
    (5, "c_mktsegment", "MACHINERY", "tricky: changed here, then reverted below"),
]


def show(con: duckdb.DuckDBPyConnection, label: str) -> None:
    print(f"\n{label}")
    rows = con.execute(
        "select c_custkey, c_mktsegment, c_acctbal, c_address, c_phone "
        "from main.customer where c_custkey between 1 and 5 order by c_custkey"
    ).fetchall()
    for r in rows:
        print("  ", r)


def main() -> None:
    con = duckdb.connect(str(DB_PATH))
    show(con, "BEFORE")

    original_segment_5 = con.execute(
        "select c_mktsegment from main.customer where c_custkey = 5"
    ).fetchall()[0][0]

    for custkey, column, value, why in CHANGES:
        con.execute(f"update main.customer set {column} = ? where c_custkey = ?", [value, custkey])
        print(f"customer {custkey}: {column} -> {value!r}  ({why})")

    # Customer 5: revert before the next snapshot, so the snapshot never sees the change.
    con.execute(
        "update main.customer set c_mktsegment = ? where c_custkey = 5", [original_segment_5]
    )
    print(f"customer 5: c_mktsegment reverted -> {original_segment_5!r}")

    show(con, "AFTER")
    con.close()


if __name__ == "__main__":
    main()
