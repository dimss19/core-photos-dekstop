"""SQLite database layer. WAL mode, Python-only read/write, Flutter via API only."""
import sqlite3
from contextlib import contextmanager


class Database:
    def __init__(self, path: str):
        self._path = path
        self._conn: sqlite3.Connection | None = None

    def connect(self) -> None:
        if self._conn is not None:
            return
        self._conn = sqlite3.connect(self._path, isolation_level=None)
        self._conn.execute('PRAGMA journal_mode=WAL')
        self._conn.row_factory = sqlite3.Row

    def close(self) -> None:
        if self._conn is not None:
            self._conn.close()
            self._conn = None

    @contextmanager
    def transaction(self):
        if self._conn is None:
            raise RuntimeError('Database not connected')
        cur = self._conn.cursor()
        try:
            yield cur
            self._conn.commit()
        except Exception:
            self._conn.rollback()
            raise
        finally:
            cur.close()

    def cursor(self) -> sqlite3.Cursor:
        if self._conn is None:
            raise RuntimeError('Database not connected')
        return self._conn.cursor()

    @property
    def last_row_id(self) -> int:
        return self._conn.lastrowid if self._conn else 0

    @property
    def rowcount(self) -> int:
        return self._conn.total_changes if self._conn else 0
