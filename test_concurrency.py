#!/usr/bin/env python3
"""
Concurrency benchmark: the project's centerpiece demonstration.

100 threads x 10 transfers = 1,000 concurrent transfers among 10 accounts.

Two modes:
  safe  (default) - via CALL transfer_funds() at REPEATABLE READ.
                    All four correctness assertions must PASS.
  naive           - raw read-then-write SQL with no row locks.
                    Demonstrates lost updates: assertions FAIL.
                    Run this at the viva to show WHY the procedure exists.

Usage:
    python test_concurrency.py            # safe mode
    python test_concurrency.py --mode naive
"""
import argparse
import os
import random
import threading
import time
from decimal import Decimal

import pymysql

CFG = dict(
    host=os.getenv("DB_HOST", "127.0.0.1"),
    port=int(os.getenv("DB_PORT", "3306")),
    user=os.getenv("DB_USER", "root"),
    password=os.getenv("DB_PASS", "rootpass"),
    database="bankdb",
)

THREADS = 100
TRANSFERS_PER_THREAD = 10
NUM_ACCOUNTS = 10
SEED_BALANCE = Decimal("100000.00")

deadlock_retries = 0
failed_transfers = 0
lock = threading.Lock()


def setup(conn):
    """Create a clean benchmark branch with NUM_ACCOUNTS seeded accounts."""
    cur = conn.cursor()
    cur.execute("INSERT INTO branches (ifsc_code, name, city) VALUES "
                "(CONCAT('BENCH', LPAD(FLOOR(RAND()*999999),6,'0')), 'Bench Branch', 'BenchCity')")
    branch = cur.lastrowid
    accounts = []
    for i in range(NUM_ACCOUNTS):
        cur.execute(
            "INSERT INTO accounts (account_no, branch_id, account_type, balance) "
            "VALUES (LPAD(FLOOR(RAND()*999999999999),12,'0'), %s, 'SAVINGS', %s)",
            (branch, SEED_BALANCE))
        acc = cur.lastrowid
        cur.execute(
            "INSERT INTO transactions (account_id, txn_type, amount, balance_after, narration) "
            "VALUES (%s,'DEPOSIT',%s,%s,'bench seed')", (acc, SEED_BALANCE, SEED_BALANCE))
        accounts.append(acc)
    conn.commit()
    return accounts


def worker_safe(accounts):
    global deadlock_retries, failed_transfers
    conn = pymysql.connect(**CFG)
    cur = conn.cursor()
    for _ in range(TRANSFERS_PER_THREAD):
        src, dst = random.sample(accounts, 2)
        amt = round(random.uniform(1, 500), 2)
        for attempt in range(5):
            try:
                cur.execute("CALL transfer_funds(%s,%s,%s,'bench')", (src, dst, amt))
                conn.commit()
                break
            except pymysql.MySQLError as e:
                errno = e.args[0] if e.args else None
                if errno in (1213, 1205):  # deadlock / lock wait timeout
                    with lock:
                        deadlock_retries += 1
                    conn.rollback()
                    time.sleep(0.01 * (attempt + 1))
                elif errno == 1644:  # SIGNAL 45000, e.g. insufficient funds
                    conn.rollback()
                    with lock:
                        failed_transfers += 1
                    break
                else:
                    raise
        else:
            with lock:
                failed_transfers += 1
    conn.close()


def worker_naive(accounts):
    """Deliberately broken: read-modify-write with NO row locks."""
    conn = pymysql.connect(**CFG)
    cur = conn.cursor()
    cur.execute("SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED")
    for _ in range(TRANSFERS_PER_THREAD):
        src, dst = random.sample(accounts, 2)
        amt = Decimal(str(round(random.uniform(1, 500), 2)))
        cur.execute("SELECT balance FROM accounts WHERE account_id=%s", (src,))
        src_bal = cur.fetchone()[0]
        cur.execute("SELECT balance FROM accounts WHERE account_id=%s", (dst,))
        dst_bal = cur.fetchone()[0]
        if src_bal < amt:
            continue
        # the race: another thread can update between our read and this write
        cur.execute("UPDATE accounts SET balance=%s WHERE account_id=%s", (src_bal - amt, src))
        cur.execute("UPDATE accounts SET balance=%s WHERE account_id=%s", (dst_bal + amt, dst))
        cur.execute(
            "INSERT INTO transactions (account_id, txn_type, amount, balance_after, transfer_group, narration) "
            "VALUES (%s,'TRANSFER_OUT',%s,%s,UUID(),'naive')", (src, amt, src_bal - amt))
        cur.execute(
            "INSERT INTO transactions (account_id, txn_type, amount, balance_after, narration) "
            "VALUES (%s,'TRANSFER_IN',%s,%s,'naive')", (dst, amt, dst_bal + amt))
        conn.commit()
    conn.close()


def check(conn, accounts, expect_pass):
    cur = conn.cursor()
    placeholders = ",".join(["%s"] * len(accounts))
    results = []

    # 1. Conservation: total money unchanged
    cur.execute(f"SELECT SUM(balance) FROM accounts WHERE account_id IN ({placeholders})", accounts)
    total = cur.fetchone()[0]
    expected = SEED_BALANCE * NUM_ACCOUNTS
    results.append(("Conservation of money", total == expected,
                    f"total={total} expected={expected}"))

    # 2. Ledger invariant: balance == signed sum of ledger rows
    cur.execute(f"""
        SELECT COUNT(*) FROM accounts a
        WHERE a.account_id IN ({placeholders})
          AND a.balance <> (
              SELECT COALESCE(SUM(CASE WHEN txn_type IN ('DEPOSIT','TRANSFER_IN') THEN amount
                                       ELSE -amount END), 0)
                FROM transactions t WHERE t.account_id = a.account_id)
    """, accounts)
    bad = cur.fetchone()[0]
    results.append(("Ledger invariant (balance = sum of entries)", bad == 0,
                    f"{bad} account(s) violate the invariant"))

    # 3. Double entry: every transfer_group has exactly 2 legs, equal amounts
    cur.execute(f"""
        SELECT COUNT(*) FROM (
            SELECT transfer_group
              FROM transactions
             WHERE transfer_group IS NOT NULL
               AND account_id IN ({placeholders})
             GROUP BY transfer_group
            HAVING COUNT(*) <> 2 OR MIN(amount) <> MAX(amount)
        ) x
    """, accounts)
    bad = cur.fetchone()[0]
    results.append(("Double-entry pairing", bad == 0, f"{bad} broken group(s)"))

    # 4. Auditability: one audit row per balance change
    cur.execute(f"""
        SELECT
          (SELECT COUNT(*) FROM audit_log WHERE account_id IN ({placeholders})),
          (SELECT COUNT(*) FROM transactions WHERE account_id IN ({placeholders})
            AND narration IN ('bench','naive'))
    """, accounts + accounts)
    audits, txns = cur.fetchone()
    results.append(("Audit trail present", audits >= txns,
                    f"audit rows={audits}, ledger rows={txns}"))

    print("\n===== ASSERTIONS =====")
    all_ok = True
    for name, ok, detail in results:
        print(f"[{'PASS' if ok else 'FAIL'}] {name}  ({detail})")
        all_ok = all_ok and ok
    print("======================")
    if expect_pass:
        print("Expected: ALL PASS (safe mode)." if all_ok
              else "!!! safe mode should never fail - investigate !!!")
    else:
        print("Expected: FAILURES (naive mode) - this is the point of the demo."
              if not all_ok else
              "Naive mode happened to pass this run - rerun; races are probabilistic.")
    return all_ok


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--mode", choices=["safe", "naive"], default="safe")
    args = ap.parse_args()

    conn = pymysql.connect(**CFG)
    accounts = setup(conn)
    print(f"mode={args.mode}: {THREADS} threads x {TRANSFERS_PER_THREAD} transfers "
          f"over {NUM_ACCOUNTS} accounts...")

    worker = worker_safe if args.mode == "safe" else worker_naive
    t0 = time.time()
    threads = [threading.Thread(target=worker, args=(accounts,)) for _ in range(THREADS)]
    for t in threads: t.start()
    for t in threads: t.join()
    dt = time.time() - t0

    total = THREADS * TRANSFERS_PER_THREAD
    print(f"\n{total} transfers in {dt:.1f}s -> {total/dt:.0f} TPS")
    if args.mode == "safe":
        print(f"deadlock retries: {deadlock_retries}, rejected transfers: {failed_transfers}")

    check(conn, accounts, expect_pass=(args.mode == "safe"))
    conn.close()


if __name__ == "__main__":
    main()
