import tempfile
import os
from app.db import Database


def test_connect_creates_file():
    with tempfile.TemporaryDirectory() as tmp:
        db_path = os.path.join(tmp, 'test.db')
        db = Database(db_path)
        db.connect()
        assert os.path.exists(db_path)
        db.close()


def test_transaction_commits():
    with tempfile.TemporaryDirectory() as tmp:
        db_path = os.path.join(tmp, 'test.db')
        db = Database(db_path)
        db.connect()
        with db.transaction() as cur:
            cur.execute('CREATE TABLE test (id INTEGER PRIMARY KEY, val TEXT)')
            cur.execute('INSERT INTO test (val) VALUES (?)', ('hello',))
        cur = db.cursor()
        cur.execute('SELECT val FROM test')
        assert cur.fetchone()[0] == 'hello'
        db.close()
