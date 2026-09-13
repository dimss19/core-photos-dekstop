# Core Photo Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Scaffold Python local core service domain + localhost API skeleton yang terbukti via pytest, tanpa hardware kamera.

**Architecture:** Python owns operation/job state + operasi berat (filename, validation, storage, imaging, API skeleton); Flutter hanya konsumen via localhost HTTP 127.0.0.1. Semua sync kecuali job; tidak ada cloud.

**Tech Stack:** Python 3.12, FastAPI, uvicorn, Pillow, pytest, httpx

## Global Constraints

- Windows 10/11 64-bit only, 1x Setup.exe (installer di plan terpisah, bukan di sini).
- Offline-first: Capture/Processing/Validation/Storage tanpa network; hanya Transfer butuh network (di luar plan ini).
- Flutter pemilik workflow state, Python pemilik job state — Python tidak menyimpan duplikat workflow.
- Localhost hanya 127.0.0.1, tidak diekspos ke network lain.
- Filename `Core01_1_000.00_2.60.jpg` dipertahankan, parser/validator terpisah dari UI.
- Tray Crop 300x200 patokan sudut Box Core, tanpa aturan crop baru.
- Anti-overwrite: HoleID sama → folder baru `_v2/_v3`, file lokal tetap ada setelah Transfer.
- `To < From` → warning + Capture disabled.
- Business logic dapat diuji independen dari UI (pytest).

---

## Scope Check

Spec tech-stack mencakup 5 subsistem (kontrak API, camera multi-vendor, DB/storage, Flutter UI, installer). Plan ini hanya **Plan 1 — Foundation**: domain Python + API skeleton yang jalan + teruji tanpa kamera. Subsistem lain menyusul sebagai plan terpisah: Plan 2 Camera adapters + LiveView, Plan 3 Flutter UI + sidecar launcher, Plan 4 Inno Setup + Transfer.

## File Structure

- `services/core_service/requirements.txt` — pinned deps (fastapi, uvicorn, pillow, pytest, httpx).
- `services/core_service/app/__init__.py` — marker paket.
- `services/core_service/app/filenames.py` — `parse_filename(name)`, `validate_filename(name)` (PRD §14).
- `services/core_service/app/validation.py` — `validate_interval(frm, to)`, `validate_tray(tray)` (PRD §8/§16).
- `services/core_service/app/storage.py` — `md5_file(path)`, `resolve_tray_dir(base, session, hole, tray_label)`, `atomic_write_json(path, data)`, `build_sidecar(...)` (PRD §15/§17).
- `services/core_service/app/imaging.py` — `crop_tray(image_path, out_jpg, out_thumb, box)` crop 300x200 + thumbnail (PRD §12/§13).
- `services/core_service/app/jobs.py` — `create_job(kind)`, `get_job(job_id)`, `finish_job(...)`, `fail_job(...)` in-memory.
- `services/core_service/app/main.py` — FastAPI: `GET /healthz`, `POST /trays/validate-interval`, `GET /jobs/{id}`.
- `services/core_service/tests/test_filenames.py`, `test_validation.py`, `test_storage.py`, `test_imaging.py`, `test_api.py` — satu file test per modul.

---

### Task 1: Repo scaffold Python service

**Files:**
- Create: `services/core_service/requirements.txt`
- Create: `services/core_service/app/__init__.py`
- Create: `services/core_service/tests/__init__.py`

**Interfaces:**
- Consumes: nothing
- Produces: importable package `app`, installed deps for Tasks 2-6

- [ ] **Step 1: Write the failing test**

```python
# services/core_service/tests/test_scaffold.py
def test_app_package_importable():
    import app
    assert app is not None
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python -m pytest services/core_service/tests/test_scaffold.py -v`
Expected: FAIL with "No module named 'app'" / collection error

- [ ] **Step 3: Write minimal implementation**

```python
# services/core_service/app/__init__.py
"""Core Photo local service domain package."""
```

```python
# services/core_service/tests/__init__.py
```

```text
# services/core_service/requirements.txt
fastapi==0.115.6
uvicorn==0.34.0
pillow==11.1.0
pytest==8.3.4
httpx==0.28.1
```

- [ ] **Step 4: Run test to verify it passes**

Run: `python -m pytest services/core_service/tests/test_scaffold.py -v`
Expected: PASS (run with `PYTHONPATH=services/core_service`)

- [ ] **Step 5: Commit**

```bash
git add services/core_service/requirements.txt services/core_service/app/__init__.py services/core_service/tests/__init__.py services/core_service/tests/test_scaffold.py
git commit -m "feat: scaffold core_service package + pinned deps"
```

---

### Task 2: Filename parser/validator (PRD §14)

**Files:**
- Create: `services/core_service/app/filenames.py`
- Test: `services/core_service/tests/test_filenames.py`

**Interfaces:**
- Consumes: nothing
- Produces: `parse_filename(name: str) -> dict`, `validate_filename(name: str) -> dict` dipakai Task 6 dan plan Flutter

- [ ] **Step 1: Write the failing test**

```python
# services/core_service/tests/test_filenames.py
from app.filenames import parse_filename, validate_filename


def test_parse_valid_filename():
    r = parse_filename("Core01_1_000.00_2.60.jpg")
    assert r == {"hole_id": "Core01", "tray_no": 1, "interval_from": 0.0, "interval_to": 2.6, "ext": "jpg"}


def test_reject_to_less_than_from():
    r = validate_filename("Core01_1_002.60_000.00.jpg")
    assert r["valid"] is False
    assert r["captureEnabled"] is False


def test_reject_bad_format():
    assert validate_filename("random.jpg")["valid"] is False
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python -m pytest services/core_service/tests/test_filenames.py -v`
Expected: FAIL with "No module named 'app.filenames'" / "cannot import name"

- [ ] **Step 3: Write minimal implementation**

```python
# services/core_service/app/filenames.py
"""Filename parser/validator. Format: {HoleID}_{TrayNo}_{From:.2f}_{To:.2f}.jpg (PRD section 14)."""
import re

_PATTERN = re.compile(r"^([A-Za-z0-9]+)_(\d+)_(\d+\.\d{2})_(\d+\.\d{2})\.(jpg|JPG)$")


def parse_filename(name: str) -> dict:
    m = _PATTERN.match(name.strip())
    if not m:
        raise ValueError(f"invalid filename: {name!r}")
    hole_id, tray_no, frm, to, ext = m.groups()
    return {
        "hole_id": hole_id,
        "tray_no": int(tray_no),
        "interval_from": float(frm),
        "interval_to": float(to),
        "ext": ext.lower(),
    }


def validate_filename(name: str) -> dict:
    try:
        p = parse_filename(name)
    except ValueError as e:
        return {"valid": False, "captureEnabled": False, "warning": str(e)}
    if p["interval_to"] < p["interval_from"]:
        return {"valid": False, "captureEnabled": False, "warning": "To < From"}
    return {"valid": True, "captureEnabled": True, "warning": "", "parsed": p}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `python -m pytest services/core_service/tests/test_filenames.py -v`
Expected: PASS (3 passed)

- [ ] **Step 5: Commit**

```bash
git add services/core_service/app/filenames.py services/core_service/tests/test_filenames.py
git commit -m "feat: add filename parser/validator per PRD-14"
```

---

### Task 3: Interval + tray validation (PRD §8/§16)

**Files:**
- Create: `services/core_service/app/validation.py`
- Test: `services/core_service/tests/test_validation.py`

**Interfaces:**
- Consumes: nothing (dipakai Task 6 `POST /trays/validate-interval`)
- Produces: `validate_interval(frm: float, to: float) -> dict`, `validate_tray(tray: dict) -> dict`

- [ ] **Step 1: Write the failing test**

```python
# services/core_service/tests/test_validation.py
from app.validation import validate_interval, validate_tray


def test_interval_invalid_disables_capture():
    r = validate_interval(20.0, 10.0)
    assert r == {"valid": False, "captureEnabled": False, "warning": "To < From"}


def test_interval_valid_enables_capture():
    r = validate_interval(10.0, 20.0)
    assert r["valid"] is True and r["captureEnabled"] is True


def test_tray_requires_hole_and_tray():
    r = validate_tray({"hole_id": "", "tray_id": "", "interval_from": 0.0, "interval_to": 1.0})
    assert r["valid"] is False
    assert "hole_id" in r["errors"]
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python -m pytest services/core_service/tests/test_validation.py -v`
Expected: FAIL with "cannot import name 'validate_interval'"

- [ ] **Step 3: Write minimal implementation**

```python
# services/core_service/app/validation.py
"""Canonical validation (PRD sections 8, 16). UI mirrors To<From lightly; this module is authoritative."""


def validate_interval(frm: float, to: float) -> dict:
    if to < frm:
        return {"valid": False, "captureEnabled": False, "warning": "To < From"}
    return {"valid": True, "captureEnabled": True, "warning": ""}


def validate_tray(tray: dict) -> dict:
    errors: dict = {}
    if not str(tray.get("hole_id", "")).strip():
        errors["hole_id"] = "Hole ID wajib diisi"
    if not str(tray.get("tray_id", "")).strip():
        errors["tray_id"] = "Tray ID wajib diisi"
    try:
        frm = float(tray.get("interval_from"))
        to = float(tray.get("interval_to"))
    except (TypeError, ValueError):
        errors["interval"] = "Interval From/To harus angka"
        return {"valid": False, "captureEnabled": False, "errors": errors}
    iv = validate_interval(frm, to)
    if not iv["valid"]:
        errors["interval"] = iv["warning"]
    valid = not errors
    return {"valid": valid, "captureEnabled": valid, "errors": errors}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `python -m pytest services/core_service/tests/test_validation.py -v`
Expected: PASS (3 passed)

- [ ] **Step 5: Commit**

```bash
git add services/core_service/app/validation.py services/core_service/tests/test_validation.py
git commit -m "feat: add interval + tray validation per PRD-8/16"
```

---

### Task 4: Storage layout + anti-overwrite + MD5 + sidecar (PRD §15/§17)

**Files:**
- Create: `services/core_service/app/storage.py`
- Test: `services/core_service/tests/test_storage.py`

**Interfaces:**
- Consumes: nothing
- Produces: `md5_file(path: str) -> str`, `resolve_tray_dir(base: str, session: str, hole: str, tray_label: str) -> str`, `atomic_write_json(path: str, data: dict) -> None`, `build_sidecar(...) -> dict`

- [ ] **Step 1: Write the failing test**

```python
# services/core_service/tests/test_storage.py
from app.storage import md5_file, resolve_tray_dir


def test_md5_known_value(tmp_path):
    p = tmp_path / "a.bin"
    p.write_bytes(b"abc")
    assert md5_file(str(p)) == "900150983cd24fb0d6963f7d28e17f72"


def test_resolve_tray_dir_suffix_on_conflict(tmp_path):
    d1 = resolve_tray_dir(str(tmp_path), "S2026", "Core01", "T1_0-2.6")
    d2 = resolve_tray_dir(str(tmp_path), "S2026", "Core01", "T1_0-2.6")
    assert d1 != d2
    assert d2.endswith("_v2")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python -m pytest services/core_service/tests/test_storage.py -v`
Expected: FAIL with "cannot import name 'md5_file'"

- [ ] **Step 3: Write minimal implementation**

```python
# services/core_service/app/storage.py
"""Local storage helpers (PRD sections 15, 17). No overwrite; temp-file rename; MD5 verify."""
import hashlib
import json
import os


def md5_file(path: str) -> str:
    h = hashlib.md5()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


def resolve_tray_dir(base: str, session: str, hole: str, tray_label: str) -> str:
    """Return new tray dir path, creating it. Appends _v2/_v3 if HoleID/Tray already exists."""
    target = os.path.join(base, session, hole, tray_label)
    if not os.path.exists(target):
        os.makedirs(target)
        return target
    i = 2
    while True:
        cand = f"{target}_v{i}"
        if not os.path.exists(cand):
            os.makedirs(cand)
            return cand
        i += 1


def atomic_write_json(path: str, data: dict) -> None:
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)
    os.replace(tmp, path)


def build_sidecar(hole_id: str, tray_id: str, frm: float, to: float, filename: str,
                  md5: str, session: dict, extra: dict | None = None) -> dict:
    sidecar = {
        "hole_id": hole_id, "tray_id": tray_id,
        "interval_from": frm, "interval_to": to,
        "filename": filename, "md5": md5,
        "date": session.get("date"), "operator": session.get("operator"), "site": session.get("site"),
    }
    if extra:
        sidecar.update(extra)
    return sidecar
```

- [ ] **Step 4: Run test to verify it passes**

Run: `python -m pytest services/core_service/tests/test_storage.py -v`
Expected: PASS (2 passed)

- [ ] **Step 5: Commit**

```bash
git add services/core_service/app/storage.py services/core_service/tests/test_storage.py
git commit -m "feat: add storage layout anti-overwrite + md5 + sidecar per PRD-15/17"
```

---

### Task 5: Tray crop 300x200 JPG + thumbnail (PRD §12/§13)

**Files:**
- Create: `services/core_service/app/imaging.py`
- Test: `services/core_service/tests/test_imaging.py`

**Interfaces:**
- Consumes: RAW/JPG file path on disk
- Produces: `crop_tray(image_path: str, out_jpg: str, out_thumb: str, box: tuple) -> dict` with `box=(x, y)` anchor sudut Box Core, ukuran tetap 300x200

- [ ] **Step 1: Write the failing test**

```python
# services/core_service/tests/test_imaging.py
from PIL import Image
from app.imaging import crop_tray


def test_crop_produces_300x200_and_thumb(tmp_path):
    src = tmp_path / "raw.jpg"
    Image.new("RGB", (800, 600), (200, 30, 30)).save(src)
    out_jpg = tmp_path / "out.jpg"
    out_thumb = tmp_path / "thumb.jpg"
    r = crop_tray(str(src), str(out_jpg), str(out_thumb), (10, 20))
    assert r["size"] == [300, 200]
    assert out_jpg.exists() and out_thumb.exists()
    assert Image.open(out_jpg).size == (300, 200)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python -m pytest services/core_service/tests/test_imaging.py -v`
Expected: FAIL with "cannot import name 'crop_tray'"

- [ ] **Step 3: Write minimal implementation**

```python
# services/core_service/app/imaging.py
"""Tray crop 300x200 anchored at Box Core corner (x, y). No other crop rules (PRD section 13)."""
from PIL import Image

CROP_W, CROP_H = 300, 200


def crop_tray(image_path: str, out_jpg: str, out_thumb: str, box: tuple) -> dict:
    x, y = int(box[0]), int(box[1])
    with Image.open(image_path) as im:
        im = im.convert("RGB")
        x = max(0, min(x, max(0, im.width - CROP_W)))
        y = max(0, min(y, max(0, im.height - CROP_H)))
        cropped = im.crop((x, y, x + CROP_W, y + CROP_H))
        cropped.save(out_jpg, "JPEG", quality=92)
        thumb = cropped.copy()
        thumb.thumbnail((256, 256))
        thumb.save(out_thumb, "JPEG", quality=85)
    return {"size": [CROP_W, CROP_H], "anchor": [x, y], "jpg": out_jpg, "thumb": out_thumb}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `python -m pytest services/core_service/tests/test_imaging.py -v`
Expected: PASS (1 passed)

- [ ] **Step 5: Commit**

```bash
git add services/core_service/app/imaging.py services/core_service/tests/test_imaging.py
git commit -m "feat: add tray crop 300x200 jpg+thumb per PRD-12/13"
```

---

### Task 6: FastAPI localhost skeleton + jobs

**Files:**
- Create: `services/core_service/app/jobs.py`
- Create: `services/core_service/app/main.py`
- Test: `services/core_service/tests/test_api.py`

**Interfaces:**
- Consumes: `validate_interval` (Task 3), `validate_filename` (Task 2)
- Produces: `GET /healthz`, `POST /trays/validate-interval`, `GET /jobs/{id}` untuk Flutter dan plan berikutnya

- [ ] **Step 1: Write the failing test**

```python
# services/core_service/tests/test_api.py
from fastapi.testclient import TestClient
from app.main import create_app


def test_healthz():
    c = TestClient(create_app())
    r = c.get("/healthz")
    assert r.status_code == 200
    assert r.json()["ok"] is True


def test_validate_interval_endpoint_blocks_capture():
    c = TestClient(create_app())
    r = c.post("/trays/validate-interval", json={"from": 20.0, "to": 10.0})
    assert r.status_code == 200
    body = r.json()
    assert body["valid"] is False and body["captureEnabled"] is False
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python -m pytest services/core_service/tests/test_api.py -v`
Expected: FAIL with "cannot import name 'create_app'"

- [ ] **Step 3: Write minimal implementation**

```python
# services/core_service/app/jobs.py
"""In-memory job registry. Python owns job state; Flutter polls GET /jobs/{id}."""
import itertools
import time

_counter = itertools.count(1)
_jobs: dict = {}


def create_job(kind: str) -> dict:
    job_id = f"job-{next(_counter)}"
    job = {"id": job_id, "kind": kind, "status": "queued", "progress": 0, "result": None, "error": None, "ts": time.time()}
    _jobs[job_id] = job
    return job


def get_job(job_id: str) -> dict | None:
    return _jobs.get(job_id)


def finish_job(job_id: str, result: dict) -> None:
    _jobs[job_id].update(status="done", progress=100, result=result)


def fail_job(job_id: str, error: str) -> None:
    _jobs[job_id].update(status="error", error=error)
```

```python
# services/core_service/app/main.py
"""Localhost API skeleton. Bind 127.0.0.1 only at runtime; no network exposure."""
from fastapi import FastAPI
from app.jobs import get_job
from app.validation import validate_interval

VERSION = "0.1.0"


def create_app() -> FastAPI:
    app = FastAPI(title="CorePhoto Local Service")

    @app.get("/healthz")
    def healthz() -> dict:
        return {"ok": True, "version": VERSION, "camera": "unknown", "db": "ok"}

    @app.post("/trays/validate-interval")
    def tray_validate_interval(payload: dict) -> dict:
        return validate_interval(float(payload["from"]), float(payload["to"]))

    @app.get("/jobs/{job_id}")
    def job_status(job_id: str) -> dict:
        job = get_job(job_id)
        if job is None:
            return {"status": "error", "error": f"unknown job {job_id}"}
        return job

    return app


app = create_app()
```

- [ ] **Step 4: Run test to verify it passes**

Run: `python -m pytest services/core_service/tests/test_api.py -v`
Expected: PASS (2 passed)

- [ ] **Step 5: Commit**

```bash
git add services/core_service/app/jobs.py services/core_service/app/main.py services/core_service/tests/test_api.py
git commit -m "feat: add localhost api skeleton healthz + validate-interval + jobs"
```

---

### Task 7: Full suite gate + push

**Files:**
- Modify: none (verification only)

- [ ] **Step 1: Run full suite**

Run: `python -m pytest services/core_service/tests -v`
Expected: PASS (all 11+1 scaffold tests; scaffold test boleh dihapus setelah ini stabil)

- [ ] **Step 2: Push**

```bash
git push origin main
```
Expected: up-to-date remote `main`

## Self-Review

1. **Spec coverage:** §14 filename → Task 2; §8/§16 validation → Task 3; §15/§17 storage+sidecar+anti-overwrite+MD5 → Task 4; §12/§13 crop 300x200+JPG+thumb → Task 5; kontrak localhost/jobs/healthz → Task 6; lifecycle/installer/camera-vendor/Flutter/Transfer disengaja di luar plan ini (Plan 2-4).
2. **Placeholder scan:** tidak ada TBD/TODO/fill-in; semua langkah berisi kode aktual, perintah run eksplisit, dan pesan commit eksplisit.
3. **Type consistency:** `validate_interval → {valid, captureEnabled, warning}` dipakai identik di Task 3 dan endpoint Task 6; `crop_tray → {size, anchor, jpg, thumb}`; `get_job → dict|None`; `parse_filename → {hole_id, tray_no, interval_from, interval_to, ext}`.
