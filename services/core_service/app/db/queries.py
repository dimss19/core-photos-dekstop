"""Database queries. All business rules live in validation.py/filenames.py; this module only persists."""
import time

from app.db import Database


def _now() -> float:
    return time.time()


def _next_id(cur, table: str, prefix: str) -> str:
    cur.execute(f'SELECT COUNT(*) FROM {table}')
    return f"{prefix}{cur.fetchone()[0] + 1}"


# --- sessions ---

def create_session(db: Database, date: str, operator: str, site: str) -> dict:
    with db.transaction() as cur:
        sid = _next_id(cur, "sessions", "s")
        cur.execute(
            'INSERT INTO sessions (id, date, operator, site, created_at) VALUES (?, ?, ?, ?, ?)',
            (sid, str(date), str(operator), str(site), _now()),
        )
    return get_session(db, sid)


def list_sessions(db: Database) -> list:
    cur = db.cursor()
    cur.execute('SELECT id, date, operator, site, created_at FROM sessions ORDER BY id')
    return [dict(r) for r in cur.fetchall()]


def get_session(db: Database, sid: str) -> dict | None:
    cur = db.cursor()
    cur.execute('SELECT id, date, operator, site, created_at FROM sessions WHERE id = ?', (sid,))
    row = cur.fetchone()
    return dict(row) if row else None


# --- trays ---

def create_tray(db: Database, session_id: str, hole_id: str, tray_id: str, frm: float, to: float,
                rows: int = 0, length: float | None = None, width: float | None = None,
                comments: str = "") -> dict:
    with db.transaction() as cur:
        tid = _next_id(cur, "trays", "t")
        cur.execute(
            '''INSERT INTO trays (id, session_id, hole_id, tray_id, interval_from, interval_to,
                                  rows, length, width, comments, created_at)
               VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
            (tid, session_id, hole_id, tray_id, float(frm), float(to), int(rows), length, width, str(comments), _now()),
        )
    return get_tray(db, tid)


def get_tray(db: Database, tid: str) -> dict | None:
    cur = db.cursor()
    cur.execute('SELECT * FROM trays WHERE id = ?', (tid,))
    row = cur.fetchone()
    return dict(row) if row else None


def set_tray_validation(db: Database, tid: str, status: str) -> None:
    with db.transaction() as cur:
        cur.execute('UPDATE trays SET validation = ? WHERE id = ?', (status, tid))


_ALLOWED_TRAY_FIELDS = ("hole_id", "tray_id", "interval_from", "interval_to",
                        "rows", "length", "width", "comments")


def update_tray(db: Database, tid: str, fields: dict) -> dict | None:
    """Correction (PRD §16): tulis field baru + reset validation (wajib re-validate)."""
    from app.validation import validate_tray as _validate
    tray = get_tray(db, tid)
    if tray is None:
        return None
    merged = dict(tray)
    for k in _ALLOWED_TRAY_FIELDS:
        if k in fields and fields[k] is not None:
            merged[k] = fields[k]
    check = _validate({k: merged.get(k) for k in ("hole_id", "tray_id", "interval_from", "interval_to")})
    if not check["valid"]:
        raise ValueError(check["errors"].get("interval") or "; ".join(check["errors"].values()))
    with db.transaction() as cur:
        cur.execute(
            '''UPDATE trays SET hole_id = ?, tray_id = ?, interval_from = ?, interval_to = ?,
                   rows = ?, length = ?, width = ?, comments = ?, validation = NULL WHERE id = ?''',
            (str(merged["hole_id"]), str(merged["tray_id"]), float(merged["interval_from"]),
             float(merged["interval_to"]), int(merged.get("rows") or 0), merged.get("length"),
             merged.get("width"), str(merged.get("comments") or ""), tid),
        )
    return get_tray(db, tid)


# --- photos ---

def create_photo(db: Database, tray_id: str, filename: str, raw_path: str, jpg_path: str,
                 thumb_path: str, md5: str) -> dict:
    with db.transaction() as cur:
        pid = _next_id(cur, "photos", "p")
        cur.execute(
            '''INSERT INTO photos (id, tray_id, filename, raw_path, jpg_path, thumb_path, md5, timestamp)
               VALUES (?, ?, ?, ?, ?, ?, ?, ?)''',
            (pid, tray_id, filename, raw_path, jpg_path, thumb_path, md5, _now()),
        )
        # Artefak berubah -> status validasi lama gugur, wajib re-validate.
        cur.execute('UPDATE trays SET validation = NULL WHERE id = ?', (tray_id,))
    return get_photo(db, pid)


def get_photo(db: Database, pid: str) -> dict | None:
    cur = db.cursor()
    cur.execute('SELECT * FROM photos WHERE id = ?', (pid,))
    row = cur.fetchone()
    return dict(row) if row else None


def list_photos(db: Database, hole_id: str | None = None, session_id: str | None = None) -> list:
    cur = db.cursor()
    cur.execute('''SELECT p.*, t.hole_id, t.tray_id AS tray_label, t.interval_from, t.interval_to,
                          t.validation, t.session_id
                   FROM photos p JOIN trays t ON p.tray_id = t.id''')
    out = []
    for r in cur.fetchall():
        d = dict(r)
        if hole_id and d.get("hole_id") != hole_id:
            continue
        if session_id and d.get("session_id") != session_id:
            continue
        out.append(d)
    return out


# --- transfers ---

def create_transfer(db: Database, session_id: str, selection: str, dest: str) -> dict:
    with db.transaction() as cur:
        xid = _next_id(cur, "transfers", "x")
        cur.execute(
            '''INSERT INTO transfers (id, session_id, selection, destination, status, progress, created_at)
               VALUES (?, ?, ?, ?, 'queued', 0, ?)''',
            (xid, session_id, selection, dest, _now()),
        )
    return get_transfer(db, xid)


def get_transfer(db: Database, xid: str) -> dict | None:
    cur = db.cursor()
    cur.execute('SELECT * FROM transfers WHERE id = ?', (xid,))
    row = cur.fetchone()
    return dict(row) if row else None


def update_transfer(db: Database, xid: str, status: str, progress: int, error: str | None = None) -> None:
    with db.transaction() as cur:
        cur.execute(
            '''UPDATE transfers SET status = ?, progress = ?, error = ?,
                   validated_at = CASE WHEN ? = 'success' THEN ? ELSE validated_at END
               WHERE id = ?''',
            (status, int(progress), error, status, _now(), xid),
        )
