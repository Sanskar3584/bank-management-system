# Bank Management System

A transactional core-banking database in MySQL 8, built so that money can't move without a trace.

All the money logic lives in the database. Stored procedures move money, triggers enforce the rules, and a thin FastAPI layer only signs users in and calls the procedures.

## What the database guarantees

- **Every balance change is audited.** A trigger writes the old and new balance to `audit_log` whenever an account balance changes.
- **The ledger is append-only.** Triggers reject any `UPDATE` or `DELETE` on `transactions`, so history can't be edited or removed.
- **No overdrafts.** Savings accounts can't go below zero, and current accounts can't go past their overdraft limit.
- **Transfers are double-entry.** `transfer_funds` writes a debit and a credit that share a `transfer_group` UUID, inside one transaction.
- **Large transactions are flagged.** Anything over ₹50,000 is marked `flagged` for review.
- **Loan repayments are automated.** `create_loan` works out the EMI with the standard amortisation formula and writes the full repayment schedule. `post_emi_batch` collects due EMIs one transaction at a time; an EMI the balance can't cover is marked `MISSED`, and three misses put the loan in `DEFAULT`.

## Schema

| | |
|---|---|
| **Tables (9)** | `branches`, `customers`, `accounts`, `account_holders`, `transactions`, `audit_log`, `loans`, `loan_schedule`, `daily_branch_summary` |
| **Procedures (6)** | `deposit`, `withdraw`, `transfer_funds`, `get_statement`, `create_loan`, `post_emi_batch` |
| **Triggers (6)** | `trg_prevent_overdraft`, `trg_audit_balance`, `trg_flag_large_txn`, `trg_block_ledger_update`, `trg_block_ledger_delete`, `trg_loan_default` |
| **Views (3)** | `v_account_statement`, `v_branch_summary`, `v_customer_portfolio` |

## Concurrency: the bug this project is about

A transfer written the obvious way reads both balances and then writes the new ones. Under load, two transfers read the same balance and the second write wipes out the first, so balances drift and money appears or disappears. `test_concurrency.py` shows the bug and the fix:

- **`--mode naive`** runs that read-then-write code with no row locks. Updates get lost and the checks fail. Races are random, so if one run happens to pass, run it again.
- **Safe mode (the default)** calls `transfer_funds`, which locks both accounts with `SELECT ... FOR UPDATE` in ascending account-ID order. Every transfer takes its locks in the same order, so two transfers can't each hold one account while waiting for the other.

Each run fires 1,000 transfers (100 threads × 10 transfers) across 10 fresh accounts holding ₹1,000,000 between them, then checks four invariants:

1. **Conservation:** the 10 accounts still hold ₹1,000,000 in total.
2. **Ledger invariant:** every balance equals the signed sum of that account's ledger entries.
3. **Double entry:** every `transfer_group` has exactly two legs of equal amount.
4. **Audit trail:** there are at least as many audit rows as ledger entries.

In my run, safe mode completed all 1,000 transfers at 613 TPS with all four checks passing. The script retries on deadlock or lock-wait errors and reports how many retries it needed.

## Index study: statements on a 5M-row ledger

`get_statement` filters one account's ledger by date and sorts it by time. The composite index `idx_txn_acct_time (account_id, created_at)` matches both the filter and the sort, so MySQL reads only that account's rows, already in order, instead of scanning the whole ledger.

On a 5M-row ledger (`python seed.py --ledger 5000000`), the statement query went from 9.76 s to 3.26 s in my run and examined about 50x fewer rows. The speed-up is smaller than the row reduction because each row found through the index still needs a lookup into the table, while a full scan reads pages in order.

To compare on your machine, run the same query with and without the index:

```sql
-- an account that received bulk rows
SET @acc = (SELECT account_id FROM transactions WHERE narration = 'bulk seed' LIMIT 1);

EXPLAIN ANALYZE
SELECT txn_id, txn_type, amount, balance_after, narration, created_at
  FROM transactions
 WHERE account_id = @acc AND created_at >= '2000-01-01' AND created_at < '2100-01-02'
 ORDER BY created_at, txn_id;

EXPLAIN ANALYZE
SELECT txn_id, txn_type, amount, balance_after, narration, created_at
  FROM transactions IGNORE INDEX (idx_txn_acct_time)
 WHERE account_id = @acc AND created_at >= '2000-01-01' AND created_at < '2100-01-02'
 ORDER BY created_at, txn_id;
```

The bulk rows are inserted directly, with a placeholder `balance_after`, purely to measure the index. They bypass the procedures, so the ledger invariant doesn't hold for the accounts that receive them.

## Run it

You need MySQL 8 and Python 3.

```powershell
# 1. Create the database. schema.sql is a mysqldump of tables, triggers,
#    procedures and views (no data); import it as root, since the procedures
#    are defined with DEFINER=root@localhost.
mysql -u root -p -e "CREATE DATABASE bankdb"
mysql -u root -p bankdb -e "source schema.sql"

# 2. Give the scripts your MySQL password (they also read DB_HOST, DB_PORT and DB_USER).
$env:DB_PASS = "your-mysql-password"      # bash: export DB_PASS=your-mysql-password

# 3. Seed demo data, then run the concurrency test.
pip install pymysql
python seed.py                            # 5 branches, 50 customers with savings accounts (password demo123)
python test_concurrency.py                # safe mode: all four checks should pass
python test_concurrency.py --mode naive   # shows the lost-update bug
```

`seed.py` reuses the same IFSC codes and emails, so run it once on a fresh database. For the index study, run `python seed.py --ledger 5000000` instead: it seeds the same demo data, then the bulk rows.

### Demo web app (optional)

`api/` is a thin FastAPI layer with a single-page UI where a customer can sign in, see their accounts, send a transfer, read a statement and view the branch summary. It checks that the signed-in customer owns an account before calling a procedure on it.

```powershell
cd api
pip install -r requirements.txt
uvicorn main:app --reload
```

Open http://localhost:8000 and sign in as `user0@example.com` with `demo123`; `seed.py` gives every seeded customer that password.

The dashboard's cards (total deposits, loan principal still owed and the next EMI date) come from the `v_customer_portfolio` view. A seeded customer has no loan, so to see the loan cards fill in, give one a loan:

```sql
SET @c = (SELECT customer_id FROM customers WHERE email = 'user0@example.com');
CALL create_loan(@c, 200000, 9.5, 24);   -- ₹2,00,000 at 9.5% a year over 24 months
```

## Project layout

```
schema.sql            tables, triggers, stored procedures and views (no data)
seed.py               demo branches and customers; --ledger N adds N bulk rows for the index study
test_concurrency.py   1,000 concurrent transfers checked against four invariants (safe or naive mode)
api/main.py           FastAPI layer: JWT sign-in, ownership checks, calls the procedures
api/static/           single-page demo UI
```

## Limitations

- The guarantees cover writes that go through the procedures. A direct `UPDATE` on `accounts` is still audited and overdraft-checked, but it skips the ledger.
- The demo API stores unsalted SHA-256 password hashes, every seeded customer shares one demo password, and any signed-in user can see the branch summary. A real system would use bcrypt or Argon2, per-user passwords and role checks.
