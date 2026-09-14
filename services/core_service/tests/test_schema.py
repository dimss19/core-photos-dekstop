import tempfile
import os
from app.db import Database
from app.db.schema import init_schema


def test_init_schema_creates_tables():
    with tempfile.TemporaryDirectory() as tmp:
        db_path = os.path.join(tmp, 'test.db')
        db = Database(db_path)
        db.connect()
        init_schema(db)
        cur = db.cursor()
        cur.execute("SELECT name FROM sqlite_master WHERE type='table' ORDER BY name")
        tables = [row[0] for row in cur.fetchall()]
        assert set(tables) == {'photos', 'schema_info', 'sessions', 'transfers', 'trays'}
        cur.execute('SELECT version FROM schema_info')
        assert cur.fetchone()[0] == 1
        db.close()
