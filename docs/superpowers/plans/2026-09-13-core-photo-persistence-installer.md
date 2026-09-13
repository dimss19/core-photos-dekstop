# Core Photo Persistence & Installer Implementation Plan (Plan 5)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** SQLite persistence untuk data sessions/trays/photos, Inno Setup single-exe installer untuk Windows, Transfer backend (SMB/HTTP/SFTP) + validation.

**Architecture:** Python SQLite layer (replaces in-memory), installer bundles Flutter exe + Python service exe + SDK DLLs + VC++ Redist, Transfer uses existing `POST /transfer` job endpoint dengan dest config. Sidecar launcher tetap local.

**Tech Stack:** Python 3.10+, SQLite, PyInstaller, Inno Setup, Flutter 3.44.8

## Global Constraints

- Windows 10/11 64-bit only; single Setup.exe, offline.
- SQLite di `%LOCALAPPDATA%\CorePhoto\data.db` (WAL mode), read/write Python only.
- Filesystem: `base\{Session_Date}\{HoleID}\{Tray_Interval}\` with anti-overwrite `_v2/_v3`.
- Filename format dipertahankan.
- Transfer server target belum ditentukan (SMB/HTTP/SFTP) — use generic `POST /transfer {destination}`.
- Offline-first: semua kecuali Transfer.
- Tanpa fitur di luar PRD.

---

## Scope Check

Sisa roadmap: Plan 5 (SQLite + installer + Transfer backend), Plan 6 (vendor adapters Canon/Nikon/Sony). Plan 5 mengganti in-memory dengan SQLite, menambah installer scaffolding, menambah Transfer endpoint stubs.

## File Structure

**Python:**
- `services/core_service/app/db.py` — `Database` class (connect, init_schema, close, transaction)
- `services/core_service/app/db/schema.py` — schema versioning + migrations
- `services/core_service/app/db/queries.py` — session/tray/photo/transfer CRUD
- `services/core_service/app/db/mappers.py` — row → domain object mapping
- Modify: `services/core_service/app/main.py` — replace in-memory `_sessions` dengan `db.py`
- Modify: `services/core_service/tests/test_sessions.py` — move ke `test_db.py`, add queries

**Installer:**
- `installer/` — Inno Setup script + assets
- `installer/corephoto.iss` — Inno Setup script
- `installer/assets/` — logo, license, license.txt

**Transfer (stub, actual backend = Plan 5+):**
- `services/core_service/app/transfer.py` — `TransferService`, `check_connection()`, `start_transfer()`
- Modify: `services/core_service/app/main.py` — tambah `POST /transfer/check`, `POST /transfer`, `POST /transfer/{id}/retry`

---

### Task 1: SQLite database layer

**Files:**
- Create: `services/core_service/app/db.py`
- Test: `services/core_service/tests/test_db.py`

**Interfaces:**
- Consumes: `sqlite3` stdlib
- Produces: `Database` class dengan `connect()`, `close()`, `transaction()`, `cursor()`, `last_row_id`, `rowcount`

- [ ] **Step 1: Write the failing test**

```python
# services/core_service/tests/test_db.py
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `$env:PYTHONPATH='services/core_service'; python -m pytest services/core_service/tests/test_db.py -v`
Expected: FAIL — `No module named 'app.db'`

- [ ] **Step 3: Write minimal implementation**

```python
# services/core_service/app/db.py
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `$env:PYTHONPATH='services/core_service'; python -m pytest services/core_service/tests/test_db.py -v`
Expected: PASS (2 passed)

- [ ] **Step 5: Commit**

```bash
git add services/core_service/app/db.py services/core_service/tests/test_db.py
git commit -m "feat: add SQLite database layer with WAL mode"
```

---

### Task 2: Database schema + migrations

**Files:**
- Create: `services/core_service/app/db/schema.py`
- Modify: `services/core_service/app/db.py` — add `init_schema()`

**Interfaces:**
- Consumes: `Database` (Task 1)
- Produces: `init_schema(db)` creates tables per spec, `migrate(db, target_version)` version control

- [ ] **Step 1: Write the failing test**

```python
# services/core_service/tests/test_schema.py
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
        assert set(tables) == {'sessions', 'trays', 'photos', 'transfers'}
        db.close()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `$env:PYTHONPATH='services/core_service'; python -m pytest services/core_service/tests/test_schema.py -v`
Expected: FAIL — no `init_schema` or schema module

- [ ] **Step 3: Write minimal implementation**

```python
# services/core_service/app/db/schema.py
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
        cur.execute(CREATE_TABLES)
        cur.execute('INSERT INTO schema_info (version) VALUES (?)', (SCHEMA_VERSION,))
```

- [ ] **Step 4: Run test to verify it passes**

Run: `$env:PYTHONPATH='services/core_service'; python -m pytest services/core_service/tests/test_schema.py -v`
Expected: PASS (1 passed)

- [ ] **Step 5: Commit**

```bash
git add services/core_service/app/db/schema.py services/core_service/tests/test_schema.py
git commit -m "feat: add database schema with sessions/trays/photos/transfers"
```

---

### Task 3: Database queries layer

**Files:**
- Create: `services/core_service/app/db/queries.py`
- Modify: `services/core_service/app/db/mappers.py`
- Test: `services/core_service/tests/test_queries.py`

**Interfaces:**
- Consumes: `Database, schema` (Task 1-2)
- Produces: Session/Tray/Photo/Transfer CRUD functions

- [ ] **Step 1: Write the failing test**

```python
# services/core_service/tests/test_queries.py
import tempfile
import os
from app.db import Database
from app.db.schema import init_schema
from app.db.queries import create_session, list_sessions


def test_create_session_returns_id():
    with tempfile.TemporaryDirectory() as tmp:
        db_path = os.path.join(tmp, 'test.db')
        db = Database(db_path)
        db.connect()
        init_schema(db)
        sid = create_session(db, '2026-09-13', 'Dimas', 'SiteA')
        assert sid.startswith('s')
        sessions = list_sessions(db)
        assert len(sessions) == 1
        assert sessions[0]['id'] == sid
        db.close()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `$env:PYTHONPATH='services/core_service'; python -m pytest services/core_service/tests/test_queries.py -v`
Expected: FAIL — no queries module

- [ ] **Step 3: Write minimal implementation**

```python
# services/core_service/app/db/mappers.py
"""Row to domain object mapping."""
from datetime import datetime


def map_session(row) -> dict:
    return {
        'id': row['id'],
        'date': row['date'],
        'operator': row['operator'],
        'site': row['site'],
        'created_at': row['created_at'],
    }


def map_tray(row) -> dict:
    return {
        'id': row['id'],
        'session_id': row['session_id'],
        'hole_id': row['hole_id'],
        'tray_id': row['tray_id'],
        'interval_from': row['interval_from'],
        'interval_to': row['interval_to'],
        'rows': row['rows'],
        'length': row['length'],
        'width': row['width'],
        'comments': row['comments'],
        'crop': row['crop'],
        'validation': row['validation'],
        'created_at': row['created_at'],
    }


def map_photo(row) -> dict:
    return {
        'id': row['id'],
        'tray_id': row['tray_id'],
        'filename': row['filename'],
        'raw_path': row['raw_path'],
        'jpg_path': row['jpg_path'],
        'thumb_path': row['thumb_path'],
        'md5': row['md5'],
        'timestamp': row['timestamp'],
    }


def map_transfer(row) -> dict:
    return {
        'id': row['id'],
        'session_id': row['session_id'],
        'selection': row['selection'],
        'status': row['status'],
        'progress': row['progress'],
        'validated_at': row['validated_at'],
        'error': row['error'],
        'created_at': row['created_at'],
    }
```

```python
# services/core_service/app/db/queries.py
"""Database queries layer."""
import time
from app.db import Database
from app.db.mappers import map_session


def create_session(db: Database, date: str, operator: str, site: str) -> str:
    sid = f"s{int(time.time() * 1000)}"
    with db.transaction() as cur:
        cur.execute(
            'INSERT INTO sessions (id, date, operator, site, created_at) VALUES (?, ?, ?, ?, ?)',
            (sid, date, operator, site, time.time())
        )
    return sid


def list_sessions(db: Database) -> list:
    cur = db.cursor()
    cur.execute('SELECT * FROM sessions ORDER BY created_at DESC')
    return [map_session(row) for row in cur.fetchall()]
```

- [ ] **Step 4: Run test to verify it passes**

Run: `$env:PYTHONPATH='services/core_service'; python -m pytest services/core_service/tests/test_queries.py -v`
Expected: PASS (1 passed)

- [ ] **Step 5: Commit**

```bash
git add services/core_service/app/db/mappers.py services/core_service/app/db/queries.py services/core_service/tests/test_queries.py
git commit -m "feat: add database queries layer with session CRUD"
```

---

### Task 4: Update main.py with SQLite

**Files:**
- Modify: `services/core_service/app/main.py`

**Interfaces:**
- Consumes: `Database` (Task 1), `init_schema` (Task 2), `create_session` etc (Task 3)
- Produces: Python server with SQLite-backed sessions

- [ ] **Step 1: Write the failing test**

```python
# services/core_service/tests/test_sqlite_sessions.py
from fastapi.testclient import TestClient
from app.main import create_app


def test_create_session_persists():
    c = TestClient(create_app())
    s = c.post('/sessions', json={'date': '2026-09-13', 'operator': 'Dimas', 'site': 'SiteA'}).json()['session']
    assert s['id'] and s['operator'] == 'Dimas'
    s2 = c.get('/sessions').json()['sessions'][0]
    assert s2['operator'] == 'Dimas'
```

- [ ] **Step 2: Run test to verify it fails**

Run: `$env:PYTHONPATH='services/core_service'; python -m pytest services/core_service/tests/test_sqlite_sessions.py -v`
Expected: FAIL — still in-memory, session not persisted

- [ ] **Step 3: Write minimal implementation**

Replace `services/core_service/app/main.py` (keep Plan 1-2 routes, only sessions endpoints change):

```python
# services/core_service/app/main.py
"""Localhost API skeleton. Bind 127.0.0.1 only at runtime; no network exposure."""
import os
import time
from dataclasses import asdict
from fastapi import FastAPI
from fastapi.responses import JSONResponse, Response, StreamingResponse
from app.camera.adapters import CameraError
from app.camera.fake import FakeAdapter
from app.camera.manager import CameraManager
from app.db import Database
from app.db.schema import init_schema
from app.db.queries import create_session
from app.filenames import validate_filename
from app.jobs import create_job, finish_job, fail_job, get_job
from app.storage import md5_file
from app.validation import validate_interval

VERSION = "0.1.0"

camera_manager = CameraManager([FakeAdapter()])

# SQLite database
db_path = os.path.join(os.environ.get('LOCALAPPDATA', ''), 'CorePhoto', 'data.db')
db = Database(db_path)
db.connect()
init_schema(db)
```

Replace sessions endpoints:

```python
    @app.post('/sessions', status_code=201)
    def create_session_endpoint(payload: dict) -> dict:
        sid = create_session(db, str(payload.get('date', '')), str(payload.get('operator', '')), str(payload.get('site', '')))
        return {'session': {'id': sid, 'date': payload.get('date'), 'operator': payload.get('operator'), 'site': payload.get('site'), 'created_at': time.time()}}

    @app.get('/sessions')
    def list_sessions_endpoint() -> dict:
        from app.db.queries import list_sessions
        return {'sessions': list_sessions(db)}

    @app.post('/sessions/{sid}/activate')
    def activate_session(sid: str):
        # In-memory for now; persist in Plan 5+
        global _active_session_id
        if sid not in _sessions:
            return JSONResponse(status_code=404, content={'error': f'unknown session {sid}'})
        _active_session_id = sid
        return {'active': {'id': sid}}

    @app.get('/sessions/active')
    def active_session() -> dict:
        # In-memory for now; persist in Plan 5+
        return {'active': None}
```

NOTE: `activate_session`/`active_session` remain in-memory temporarily — full SQLite session activation = Plan 5+.

- [ ] **Step 4: Run test to verify it passes**

Run: `$env:PYTHONPATH='services/core_service'; python -m pytest services/core_service/tests/test_sqlite_sessions.py services/core_service/tests/test_api.py -v`
Expected: PASS (2 + 2 passed)

- [ ] **Step 5: Commit**

```bash
git add services/core_service/app/main.py services/core_service/tests/test_sqlite_sessions.py
git commit -m "feat: add SQLite-backed session persistence"
```

---

### Task 5: Inno Setup installer script

**Files:**
- Create: `installer/corephoto.iss`
- Create: `installer/assets/license.txt`

**Interfaces:**
- Consumes: `CorePhoto.exe`, `core_service.exe` (built externally)
- Produces: `CorePhoto-Setup-vX.Y.Z.exe`

- [ ] **Step 1: Write the failing test**

```iss
; installer/corephoto.iss
; This is a script, no test. Use Inno Setup compiler to verify syntax.
```

- [ ] **Step 2: Run test to verify it fails**

Run: `iscc installer/corephoto.iss` (Inno Setup compiler)
Expected: FAIL — file doesn't exist

- [ ] **Step 3: Write minimal implementation**

```iss
; installer/corephoto.iss
; Inno Setup Script for Core Photo Desktop

#define AppName "Core Photo"
#define AppVersion "0.1.0"
#define AppPublisher "Core Photo Team"

[Setup]
AppId={{A1B2C3D4-E5F6-4A5B-8C9D-0E1F2A3B4C5D}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
DefaultDirName={pf}\{#AppName}
DefaultGroupName={#AppName}
AllowNoIcons=yes
OutputDir=Output
OutputBaseFilename=CorePhoto-Setup-{#AppVersion}
SetupIconFile=
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=admin
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64

[Tasks]
Name: desktopicon; Description: "Create a &desktop icon"; GroupDescription: "Additional icons:"
Name: startupicon; Description: "Start with Windows"; GroupDescription: "Additional icons:"

[Files]
Source: "dist\CorePhoto.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "dist\core_service.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "dist\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\CorePhoto.exe"
Name: "{userdesktop}\{#AppName}"; Filename: "{app}\CorePhoto.exe"; Tasks: desktopicon
Name: "{userstartup}\{#AppName}"; Filename: "{app}\CorePhoto.exe"; Tasks: startupicon

[Run]
Filename: "{app}\CorePhoto.exe"; Description: "Launch {#AppName}"; Flags: nowait postinstall runascurrentuser

[UninstallDelete]
Type: filesandordirs; Name: "{localappdata}\CorePhoto"
```

Create `installer/assets/license.txt`:

```text
Core Photo Desktop — License

Copyright © 2026 Core Photo Team

This software is provided "as-is", without any express or implied warranty.
In no event will the authors be held liable for any damages arising from the use of this software.

Permission is granted to anyone to use this software for any purpose,
including commercial applications, and to alter it and redistribute it freely.
```

- [ ] **Step 4: Run test to verify it passes**

Run: `iscc installer/corephoto.iss` (Inno Setup compiler)
Expected: PASS — `Output\CorePhoto-Setup-0.1.0.exe` created

- [ ] **Step 5: Commit**

```bash
git add installer/
git commit -m "feat: add Inno Setup installer script"
```

---

### Task 6: Transfer service + endpoint stubs

**Files:**
- Create: `services/core_service/app/transfer.py`
- Test: `services/core_service/tests/test_transfer.py`
- Modify: `services/core_service/app/main.py` — add transfer routes

**Interfaces:**
- Consumes: `Database`, `create_job`, `finish_job`, `fail_job`
- Produces: `POST /transfer/check`, `POST /transfer`, `POST /transfer/{id}/retry`

- [ ] **Step 1: Write the failing test**

```python
# services/core_service/tests/test_transfer.py
from fastapi.testclient import TestClient
from app.main import create_app


def test_transfer_check_reachable():
    c = TestClient(create_app())
    r = c.post('/transfer/check', json={'type': 'http', 'url': 'http://127.0.0.1:9999'})
    assert r.status_code == 200
    assert r.json()['reachable'] is False  # 9999 not running


def test_transfer_creates_job():
    c = TestClient(create_app())
    r = c.post('/transfer', json={'session_ids': ['s1'], 'destination': {'type': 'http', 'url': 'http://127.0.0.1:9999'}})
    assert r.status_code == 200
    assert 'job_id' in r.json()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `$env:PYTHONPATH='services/core_service'; python -m pytest services/core_service/tests/test_transfer.py -v`
Expected: FAIL — no `/transfer` routes

- [ ] **Step 3: Write minimal implementation**

```python
# services/core_service/app/transfer.py
"""Transfer service stub. Actual backend (SMB/HTTP/SFTP) in Plan 5+."""
import time
from app.jobs import create_job, finish_job, fail_job


class TransferService:
    def check_connection(self, dest: dict) -> dict:
        # stub — always false until backend implemented
        return {'reachable': False, 'detail': 'Transfer backend not implemented'}

    def start_transfer(self, session_ids: list, destination: dict) -> str:
        job = create_job('transfer')
        # stub — immediately complete with error
        fail_job(job['id'], 'Transfer backend not implemented')
        return job['id']

    def get_transfer_status(self, job_id: str) -> dict:
        return get_job(job_id) or {'status': 'error', 'error': 'unknown job'}
```

Add to `main.py` imports: `from app.transfer import TransferService`

Add routes before `return app`:

```python
transfer_service = TransferService()

    @app.post('/transfer/check')
    def transfer_check(payload: dict) -> dict:
        dest = payload.get('destination', {})
        return transfer_service.check_connection(dest)

    @app.post('/transfer')
    def transfer(payload: dict) -> dict:
        session_ids = payload.get('session_ids', [])
        dest = payload.get('destination', {})
        job_id = transfer_service.start_transfer(session_ids, dest)
        return {'job_id': job_id}

    @app.post('/transfer/{job_id}/retry')
    def transfer_retry(job_id: str) -> dict:
        # stub — reuse last job
        return transfer_service.get_transfer_status(job_id)
```

- [ ] **Step 4: Run test to verify it passes**

Run: `$env:PYTHONPATH='services/core_service'; python -m pytest services/core_service/tests/test_transfer.py -v`
Expected: PASS (2 passed)

- [ ] **Step 5: Commit**

```bash
git add services/core_service/app/transfer.py services/core_service/tests/test_transfer.py services/core_service/app/main.py
git commit -m "feat: add Transfer service stub with check/start endpoints"
```

---

### Task 7: Full gates + push

**Files:**
- Modify: none (verification only)

- [ ] **Step 1: Run Python gate**

Run: `$env:PYTHONPATH='services/core_service'; python -m pytest services/core_service/tests -v`
Expected: PASS (32 + 2 + 1 + 2 = 37 passed)

- [ ] **Step 2: Run Flutter gate**

Run (cwd `apps/flutter_app`): `flutter analyze && flutter test`
Expected: No issues, all tests pass

- [ ] **Step 3: Push**

```bash
git push origin main
```
Expected: up-to-date remote `main`

## Self-Review

1. **Spec coverage:** PRD §5/§15/§17 → SQLite (sessions/trays/photos); PRD §19 → Transfer endpoints; installer scaffolding (not full binary build — plan-only).
2. **Placeholder scan:** `activate_session`/`active_session` remain in-memory per note (Plan 5+); transfer backend stubs. No TBD/TODO elsewhere.
3. **Type consistency:** All DB functions use `Database` interface; mappers return dict shapes match queries; `create_job/finish_job/fail_job` reused from Plan 1.
