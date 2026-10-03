#!/usr/bin/env python3
"""
Core Banking Transaction System - demo API layer.

Deliberately THIN: all money logic lives in MySQL stored procedures.
This layer only authenticates, validates ownership, calls procedures,
and maps database errors to HTTP responses.

Run:
    pip install -r requirements.txt
    set DB_PASS=your_mysql_root_password     (Windows; export on Linux)
    uvicorn main:app --reload
Then open http://localhost:8000
"""
import datetime
import os

import jwt
import pymysql
import pymysql.cursors
from fastapi import Depends, FastAPI, Header, HTTPException
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel, Field

SECRET = os.getenv("JWT_SECRET", "dev-secret-change-me")
TOKEN_HOURS = 8

CFG = dict(
    host=os.getenv("DB_HOST", "127.0.0.1"),
    port=int(os.getenv("DB_PORT", "3306")),
    user=os.getenv("DB_USER", "root"),
    password=os.getenv("DB_PASS", "rootpass"),
    database="bankdb",
    cursorclass=pymysql.cursors.DictCursor,
    autocommit=True,   # procedures manage their own transactions
)

app = FastAPI(title="Core Banking Demo API")


# ---------- helpers ----------
def db():
    return pymysql.connect(**CFG)


def db_error_to_http(e: pymysql.MySQLError) -> HTTPException:
    """Map MySQL errors to HTTP. 1644 = our SIGNAL 45000 business errors."""
    errno = e.args[0] if e.args else 0
    msg = e.args[1] if len(e.args) > 1 else str(e)
    if errno == 1644:
        return HTTPException(status_code=400, detail=msg)
    if errno in (1213, 1205):
        return HTTPException(status_code=409, detail="Busy, please retry")
    return HTTPException(status_code=500, detail=f"Database error {errno}")


def current_user(authorization: str = Header(None)) -> dict:
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Missing token")
    try:
        return jwt.decode(authorization[7:], SECRET, algorithms=["HS256"])
    except jwt.PyJWTError:
        raise HTTPException(status_code=401, detail="Invalid or expired token")


def owns_account(cur, customer_id: int, account_id: int) -> bool:
    cur.execute(
        "SELECT 1 FROM account_holders WHERE account_id=%s AND customer_id=%s",
        (account_id, customer_id))
    return cur.fetchone() is not None


# ---------- schemas ----------
class LoginIn(BaseModel):
    email: str
    password: str


class TransferIn(BaseModel):
    from_acc: int
    to_acc: int
    amount: float = Field(gt=0)
    narration: str = ""


class CashIn(BaseModel):
    account_id: int
    amount: float = Field(gt=0)
    narration: str = ""


# ---------- auth ----------
@app.post("/api/login")
def login(body: LoginIn):
    conn = db()
    try:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT customer_id, full_name FROM customers "
                "WHERE email=%s AND password_hash=SHA2(%s, 256)",
                (body.email, body.password))
            row = cur.fetchone()
        if not row:
            raise HTTPException(status_code=401, detail="Wrong email or password")
        exp = datetime.datetime.utcnow() + datetime.timedelta(hours=TOKEN_HOURS)
        token = jwt.encode(
            {"sub": str(row["customer_id"]), "name": row["full_name"], "exp": exp},
            SECRET, algorithm="HS256")
        return {"token": token, "name": row["full_name"]}
    finally:
        conn.close()


# ---------- accounts / portfolio ----------
@app.get("/api/accounts")
def my_accounts(user=Depends(current_user)):
    conn = db()
    try:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT a.account_id, a.account_no, a.account_type, a.balance, "
                "       a.status, ah.role "
                "  FROM accounts a "
                "  JOIN account_holders ah ON ah.account_id = a.account_id "
                " WHERE ah.customer_id = %s ORDER BY a.account_id",
                (int(user["sub"]),))
            return cur.fetchall()
    finally:
        conn.close()


@app.get("/api/portfolio")
def portfolio(user=Depends(current_user)):
    conn = db()
    try:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT * FROM v_customer_portfolio WHERE customer_id = %s",
                (int(user["sub"]),))
            return cur.fetchone() or {}
    finally:
        conn.close()


@app.get("/api/accounts/{account_id}/statement")
def statement(account_id: int, date_from: str = "2000-01-01",
              date_to: str = "2100-01-01", user=Depends(current_user)):
    conn = db()
    try:
        with conn.cursor() as cur:
            if not owns_account(cur, int(user["sub"]), account_id):
                raise HTTPException(status_code=403, detail="Not your account")
            cur.execute("CALL get_statement(%s, %s, %s)",
                        (account_id, date_from, date_to))
            return cur.fetchall()
    finally:
        conn.close()


# ---------- money movement (procedures do the real work) ----------
@app.post("/api/transfer")
def transfer(body: TransferIn, user=Depends(current_user)):
    conn = db()
    try:
        with conn.cursor() as cur:
            if not owns_account(cur, int(user["sub"]), body.from_acc):
                raise HTTPException(status_code=403, detail="Not your account")
            try:
                cur.execute("CALL transfer_funds(%s, %s, %s, %s)",
                            (body.from_acc, body.to_acc, body.amount,
                             body.narration or None))
            except pymysql.MySQLError as e:
                raise db_error_to_http(e)
        return {"ok": True}
    finally:
        conn.close()


@app.post("/api/deposit")
def do_deposit(body: CashIn, user=Depends(current_user)):
    conn = db()
    try:
        with conn.cursor() as cur:
            if not owns_account(cur, int(user["sub"]), body.account_id):
                raise HTTPException(status_code=403, detail="Not your account")
            try:
                cur.execute("CALL deposit(%s, %s, %s)",
                            (body.account_id, body.amount, body.narration or None))
                row = cur.fetchone()
            except pymysql.MySQLError as e:
                raise db_error_to_http(e)
        return {"ok": True, "new_balance": row["new_balance"] if row else None}
    finally:
        conn.close()


@app.post("/api/withdraw")
def do_withdraw(body: CashIn, user=Depends(current_user)):
    conn = db()
    try:
        with conn.cursor() as cur:
            if not owns_account(cur, int(user["sub"]), body.account_id):
                raise HTTPException(status_code=403, detail="Not your account")
            try:
                cur.execute("CALL withdraw(%s, %s, %s, 'WITHDRAWAL')",
                            (body.account_id, body.amount, body.narration or None))
                row = cur.fetchone()
            except pymysql.MySQLError as e:
                raise db_error_to_http(e)
        return {"ok": True, "new_balance": row["new_balance"] if row else None}
    finally:
        conn.close()


# ---------- admin ----------
@app.get("/api/admin/summary")
def admin_summary(user=Depends(current_user)):
    # Demo scope: any logged-in user may view. Real system: role check here.
    conn = db()
    try:
        with conn.cursor() as cur:
            cur.execute("SELECT * FROM v_branch_summary ORDER BY branch_id")
            return cur.fetchall()
    finally:
        conn.close()


# ---------- static frontend (must be mounted LAST) ----------
app.mount("/", StaticFiles(directory=os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "static"), html=True), name="static")
