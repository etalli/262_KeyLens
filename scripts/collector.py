
import sqlite3
import datetime
import random

DB="usage.db"

def init():
    con=sqlite3.connect(DB)
    cur=con.cursor()
    cur.execute("""
    CREATE TABLE IF NOT EXISTS usage (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        timestamp TEXT,
        model TEXT,
        repo TEXT,
        issue TEXT,
        tokens INTEGER,
        cost REAL,
        duration REAL
    )
    """)
    con.commit()
    con.close()

def mock_event():
    models=["claude-opus","claude-sonnet"]
    repos=["KeyLens","experiment","test"]
    issue=["#101","#102","#103","#104"]
    tokens=random.randint(500,5000)
    cost=round(tokens/100000*3,4)
    duration=random.uniform(1,20)
    return (
        datetime.datetime.now().isoformat(),
        random.choice(models),
        random.choice(repos),
        random.choice(issue),
        tokens,
        cost,
        duration
    )

def insert(event):
    con=sqlite3.connect(DB)
    cur=con.cursor()
    cur.execute("""
    INSERT INTO usage(timestamp,model,repo,issue,tokens,cost,duration)
    VALUES(?,?,?,?,?,?,?)
    """,event)
    con.commit()
    con.close()

if __name__=="__main__":
    init()
    for _ in range(10):
        insert(mock_event())
    print("Inserted mock usage events into usage.db")
