"""Database schema initialization and versioning."""
from app.db import Database

SCHEMA_VERSION = 1

CREATE_TABLES = """
CREATE TABLE IF NOT EXISTS sessions (
    id TEXT PRIMARY KEY,
    date TEXT NOT NULL,
    operator TEXT NOT NULL,
    site TEXT NOT NULL,
    created_at REAL NOT NULL
);

CREATE TABLE IF NOT EXISTS trays (
    id TEXT PRIMARY KEY,
    session_id TEXT NOT NULL,
    hole_id TEXT NOT NULL,
    tray_id TEXT NOT NULL,
    interval_from REAL NOT NULL,
    interval_to REAL NOT NULL,
    rows INTEGER NOT NULL,
    length REAL,
    width REAL,
    comments TEXT,
    crop BLOB,
    validation TEXT,
    created_at REAL NOT NULL,
    FOREIGN KEY (session_id) REFERENCES sessions(id)
);

CREATE TABLE IF NOT EXISTS photos (
    id TEXT PRIMARY KEY,
    tray_id TEXT NOT NULL,
    filename TEXT NOT NULL,
    raw_path TEXT NOT NULL,
    jpg_path TEXT NOT NULL,
    thumb_path TEXT NOT NULL,
    md5 TEXT NOT NULL,
    timestamp REAL NOT NULL,
    FOREIGN KEY (tray_id) REFERENCES trays(id)
);

CREATE TABLE IF NOT EXISTS transfers (
    id TEXT PRIMARY KEY,
    session_id TEXT NOT NULL,
    selection TEXT NOT NULL,
    status TEXT NOT NULL,
    progress INTEGER NOT NULL,
    validated_at REAL,
    error TEXT,
    created_at REAL NOT NULL,
    FOREIGN KEY (session_id) REFERENCES sessions(id)
);

CREATE TABLE IF NOT EXISTS schema_info (
    version INTEGER NOT NULL
);
"""


def init_schema(db: Database) -> None:
    with db.transaction() as cur:
        cur.executescript(CREATE_TABLES)
        cur.execute('INSERT INTO schema_info (version) VALUES (?)', (SCHEMA_VERSION,))
