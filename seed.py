#!/usr/bin/env python3
"""
Seed data generator for the Core Banking Transaction System.

Usage:
    pip install pymysql
    python seed.py                 # 5 branches, 50 customers, deposits
    python seed.py --ledger 100000 # + 100k random ledger transactions
    python seed.py --ledger 5000000  # index-study scale (uses batching)

Connection via env vars: DB_HOST, DB_PORT, DB_USER, DB_PASS (defaults below).
Every seeded customer can sign in to the demo app in api/ with DEMO_PASSWORD.
"""
import argparse
import os
import random
import string
import time

import pymysql

CFG = dict(
    host=os.getenv("DB_HOST", "127.0.0.1"),
    port=int(os.getenv("DB_PORT", "3306")),
    user=os.getenv("DB_USER", "root"),
    password=os.getenv("DB_PASS", "rootpass"),
    database="bankdb",
    autocommit=False,
)

FIRST = ["Aarav", "Vivaan", "Aditya", "Ananya", "Diya", "Ishaan", "Kavya",
         "Rohan", "Sanya", "Arjun", "Meera", "Kabir", "Zoya", "Dev", "Nisha"]
LAST = ["Sharma", "Verma", "Patel", "Reddy", "Singh", "Gupta", "Nair",
        "Iyer", "Das", "Mehta", "Joshi", "Kulkarni"]
CITIES = ["Mumbai", "Delhi", "Bengaluru", "Pune", "Hyderabad"]

# Stored the way the API's login checks it: SHA2(password, 256). Demo use only.
DEMO_PASSWORD = "demo123"


def rand_account_no():
    return "".join(random.choices(string.digits, k=12))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--branches", type=int, default=5)
    ap.add_argument("--customers", type=int, default=50)
    ap.add_argument("--ledger", type=int, default=0,
                    help="extra random ledger rows for the index study")
    args = ap.parse_args()

    conn = pymysql.connect(**CFG)
    cur = conn.cursor()

    # --- branches -------------------------------------------------
    branches = []
    for i in range(args.branches):
        cur.execute(
            "INSERT INTO branches (ifsc_code, name, city) VALUES (%s,%s,%s)",
            (f"SEED{i:07d}", f"{CITIES[i % len(CITIES)]} Branch {i+1}",
             CITIES[i % len(CITIES)]))
        branches.append(cur.lastrowid)
    conn.commit()
    print(f"branches: {len(branches)}")

    # --- customers + savings accounts ------------------------------
    accounts = []
    for i in range(args.customers):
        name = f"{random.choice(FIRST)} {random.choice(LAST)}"
        branch = random.choice(branches)
        cur.execute(
            "INSERT INTO customers (branch_id, full_name, email, phone, dob, kyc_status, password_hash) "
            "VALUES (%s,%s,%s,%s,%s,'VERIFIED',SHA2(%s, 256))",
            (branch, name, f"user{i}@example.com", f"8{i:09d}",
             f"{random.randint(1970, 2004)}-{random.randint(1,12):02d}-{random.randint(1,28):02d}",
             DEMO_PASSWORD))
        cust = cur.lastrowid

        opening = random.choice([5000, 10000, 25000, 50000, 100000])
        cur.execute(
            "INSERT INTO accounts (account_no, branch_id, account_type, balance) "
            "VALUES (%s,%s,'SAVINGS',%s)",
            (rand_account_no(), branch, opening))
        acc = cur.lastrowid
        cur.execute(
            "INSERT INTO account_holders (account_id, customer_id, role) "
            "VALUES (%s,%s,'PRIMARY')", (acc, cust))
        # opening-balance ledger entry keeps the invariant true from row one
        cur.execute(
            "INSERT INTO transactions (account_id, txn_type, amount, balance_after, narration) "
            "VALUES (%s,'DEPOSIT',%s,%s,'Opening balance')",
            (acc, opening, opening))
        accounts.append(acc)
    conn.commit()
    print(f"customers + savings accounts: {len(accounts)}")
    print(f"demo login: user0@example.com / {DEMO_PASSWORD}")

    # --- optional bulk ledger for the index study -------------------
    if args.ledger:
        print(f"seeding {args.ledger:,} ledger rows (batched)...")
        t0 = time.time()
        BATCH = 5000
        rows = []
        for i in range(args.ledger):
            acc = random.choice(accounts)
            amt = round(random.uniform(10, 60000), 2)
            kind = random.choice(["DEPOSIT", "WITHDRAWAL"])
            # balance_after is synthetic here - this bulk data exists purely
            # to measure index performance, and is generated OUTSIDE the
            # procedures. Document this in the report.
            rows.append((acc, kind, amt, 0.00, "bulk seed"))
            if len(rows) >= BATCH:
                cur.executemany(
                    "INSERT INTO transactions (account_id, txn_type, amount, balance_after, narration) "
                    "VALUES (%s,%s,%s,%s,%s)", rows)
                conn.commit()
                rows = []
                if (i + 1) % 100000 == 0:
                    print(f"  {i+1:,} rows ({time.time()-t0:.0f}s)")
        if rows:
            cur.executemany(
                "INSERT INTO transactions (account_id, txn_type, amount, balance_after, narration) "
                "VALUES (%s,%s,%s,%s,%s)", rows)
            conn.commit()
        print(f"ledger seeded in {time.time()-t0:.0f}s")

    cur.close()
    conn.close()
    print("done.")


if __name__ == "__main__":
    main()
