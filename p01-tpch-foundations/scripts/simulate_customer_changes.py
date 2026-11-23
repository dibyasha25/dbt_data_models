"""Simulate changes to raw TPC-H customers so the snapshot has history to record.

TPC-H data never changes on its own. Run this AFTER a first `dbt snapshot`,
then run `dbt snapshot` again and compare.

Each change also sets c_updated_at to a date inside the TPC-H order range
(1992-1998), the way a source system stamps a row when it edits it. The snapshot
uses the `timestamp` strategy, so that date becomes the new version's dbt_valid_from,
and orders placed before it still see the old version. (Dating written by Claude.)

Usage (from the p01-tpch-foundations folder):
    uv run python scripts/simulate_customer_changes.py

Note: re-running scripts/load_tpch.py --force resets the raw data.
"""

from pathlib import Path

import duckdb

DB_PATH = Path(__file__).resolve().parent.parent / "tpch.duckdb"

# (customer key, column, new value, updated_at, why it's here)
CHANGES = [
    # Customer 1 has 4 orders before 1995-01-01 and 5 after, so the point-in-time
    # join shows both segments.
    (1, "c_mktsegment", "HOUSEHOLD", "1995-01-01 00:00:00", "segment change"),
    (2, "c_address", "12 New Street", "1996-01-01 00:00:00", "address change"),
    # Customer 3 has no orders (TPC-H gives every third customer none).
    (3, "c_acctbal", 0.00, "1997-01-01 00:00:00", "balance change"),
    # Under the old `check` strategy this change was missed (c_phone wasn't a check
    # column). Under `timestamp` it is recorded, because c_updated_at moved.
    (4, "c_phone", "99-999-999-9999", "1998-01-01 00:00:00", "phone change, unwatched column"),
]


def show(con: duckdb.DuckDBPyConnection, label: str) -> None:
    print(f"\n{label}")
    rows = con.execute(
        "select c_custkey, c_mktsegment, c_acctbal, c_address, c_phone, c_updated_at "
        "from main.customer where c_custkey between 1 and 4 order by c_custkey"
    ).fetchall()
    for r in rows:
        print("  ", r)


def main() -> None:
    con = duckdb.connect(str(DB_PATH))
    show(con, "BEFORE")

    for custkey, column, value, updated_at, why in CHANGES:
        con.execute(
            f"update main.customer set {column} = ?, c_updated_at = ? where c_custkey = ?",
            [value, updated_at, custkey],
        )
        print(f"customer {custkey}: {column} -> {value!r} at {updated_at}  ({why})")

    show(con, "AFTER")
    con.close()


if __name__ == "__main__":
    main()
