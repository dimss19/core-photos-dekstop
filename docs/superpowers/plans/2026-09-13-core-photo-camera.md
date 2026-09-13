# Core Photo Camera Layer Implementation Plan (Plan 2)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Camera Integration Layer + localhost camera/capture endpoints yang terbukti via pytest tanpa hardware kamera.

**Architecture:** `ICameraAdapter` ABC + `CameraManager` (auto-detect, single active, PRD status mapping) + `FakeAdapter` (synthetic JPEG via Pillow) sebagai reference yang membuktikan kontrak; Python owns job state, capture async via job_id; Flutter hanya via localhost API.

**Tech Stack:** Python 3.10+, FastAPI, Pillow, pytest, httpx (same env as Plan 1)

## Global Constraints

- Windows 10/11 64-bit only; DSLR/Mirrorless via USB langsung, bukan webcam, bukan remote/network camera.
- Flutter pemilik workflow state, Python pemilik job state — Python hanya mengembalikan status/result/error job.
- Localhost hanya 127.0.0.1, tidak diekspos ke network lain.
- Status kamera persis: `Connected/Ready` | `Not Connected` | `Error` (PRD §6.2) — string exact, didefinisikan sekali di manager.
- Camera settings capability-based; ISO/Focus/Zoom unsupported → dikembalikan tanpa crash (PRD §6.4). ISO acuan +1200 adalah kalibrasi, bukan business rule baru.
- Generic PTP/WPD fallback hanya sesuai capability; jangan asumsikan semua kamera bisa capture via fallback.
- `To < From` → warning + Capture disabled; filename format dipertahankan; parser/validator Plan 1 dipakai ulang, tidak ditulis ulang.
- Capture/Processing/Transfer async via job_id; UI tidak boleh freeze.
- Semua offline kecuali Transfer. Tanpa fitur kamera di luar PRD.

---

## Scope Check

Spec tech-stack §3 (Camera Layer) + §2 (kontrak endpoint kamera/capture). Plan ini **hanya software + FakeAdapter yang teruji tanpa hardware**. Adapter vendor (Canon EDSDK / Nikon / Sony DLL via ctypes) disengaja DI LUAR plan ini — butuh DLL + hardware fisik (Plan 5, fase hardware). `CameraManager` menerima list adapter sehingga vendor adapters plug-in tanpa mengubah kontrak.

## File Structure

- `services/core_service/app/camera/__init__.py` — re-export `ICameraAdapter, Capabilities, CameraError, CameraManager, FakeAdapter, STATUS_*`.
- `services/core_service/app/camera/adapters.py` — `Capabilities` dataclass, `CameraError`, `ICameraAdapter` ABC (kontrak semua adapter).
- `services/core_service/app/camera/fake.py` — `FakeAdapter(ICameraAdapter)`: frame JPEG sintetis + capture tulis file (reference implementation).
- `services/core_service/app/camera/manager.py` — `STATUS_READY/STATUS_DOWN/STATUS_ERROR`, `CameraManager(adapters)`: auto-detect, single active, `status()`, `require_ready()`.
- Modify: `services/core_service/app/main.py` — tambah singleton manager + endpoint kamera/capture, endpoint Plan 1 tidak diubah.
- `services/core_service/tests/test_camera.py` — adapter + manager + endpoint kamera + MJPEG stream (1 chunk).
- `services/core_service/tests/test_capture.py` — `POST /captures` job flow (valid → done + file + md5; invalid → job error; disconnected → job error).

---

### Task 1: Adapter contract (ABC + Capabilities + CameraError)

**Files:**
- Create: `services/core_service/app/camera/__init__.py`
- Create: `services/core_service/app/camera/adapters.py`
- Test: `services/core_service/tests/test_camera_contract.py`

**Interfaces:**
- Consumes: nothing
- Produces: `ICameraAdapter` (Task 2 implements), `Capabilities`, `CameraError` (Tasks 2-5 use exact names)

- [ ] **Step 1: Write the failing test**

```python
# services/core_service/tests/test_camera_contract.py
import pytest
from app.camera.adapters import ICameraAdapter, Capabilities, CameraError


def test_abc_cannot_instantiate():
    with pytest.raises(TypeError):
        ICameraAdapter()


def test_capabilities_defaults_all_false():
    c = Capabilities()
    assert (c.supports_liveview, c.supports_iso, c.supports_focus, c.supports_zoom, c.supports_capture) == (False, False, False, False, False)


def test_dummy_subclass_satisfies_contract():
    class Dummy(ICameraAdapter):
        @property
        def name(self): return "dummy"
        def detect(self): return True
        def connect(self): pass
        def disconnect(self): pass
        def is_connected(self): return True
        def get_capabilities(self): return Capabilities(supports_capture=True)
        def start_liveview(self): pass
        def stop_liveview(self): pass
        def liveview_running(self): return False
        def grab_frame(self): return b"JPEG"
        def capture(self, dest_path): return {"path": dest_path, "md5": "x", "bytes": 0}
        def set_iso(self, value): return {"ok": False, "reason": "unsupported"}
        def set_focus(self, value): return {"ok": False, "reason": "unsupported"}
        def set_zoom(self, value): return {"ok": False, "reason": "unsupported"}
    d = Dummy()
    assert d.name == "dummy" and d.grab_frame() == b"JPEG"
    assert d.set_iso(1200) == {"ok": False, "reason": "unsupported"}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python -m pytest services/core_service/tests/test_camera_contract.py -v`
Expected: FAIL with "No module named 'app.camera'"

- [ ] **Step 3: Write minimal implementation**

```python
# services/core_service/app/camera/adapters.py
"""Universal camera adapter contract. Vendor adapters (Canon/Nikon/Sony) implement this ABC (Plan 5)."""
from abc import ABC, abstractmethod
from dataclasses import dataclass


class CameraError(Exception):
    """Raised for detect/connect/capture/liveview failures with operator-actionable message."""


@dataclass
class Capabilities:
    supports_liveview: bool = False
    supports_iso: bool = False
    supports_focus: bool = False
    supports_zoom: bool = False
    supports_capture: bool = False


class ICameraAdapter(ABC):
    @property
    @abstractmethod
    def name(self) -> str: ...

    @abstractmethod
    def detect(self) -> bool: ...

    @abstractmethod
    def connect(self) -> None: ...

    @abstractmethod
    def disconnect(self) -> None: ...

    @abstractmethod
    def is_connected(self) -> bool: ...

    @abstractmethod
    def get_capabilities(self) -> Capabilities: ...

    @abstractmethod
    def start_liveview(self) -> None: ...

    @abstractmethod
    def stop_liveview(self) -> None: ...

    @abstractmethod
    def liveview_running(self) -> bool: ...

    @abstractmethod
    def grab_frame(self) -> bytes: ...

    @abstractmethod
    def capture(self, dest_path: str) -> dict: ...

    @abstractmethod
    def set_iso(self, value) -> dict: ...

    @abstractmethod
    def set_focus(self, value) -> dict: ...

    @abstractmethod
    def set_zoom(self, value) -> dict: ...
```

```python
# services/core_service/app/camera/__init__.py
"""Camera Integration Layer public surface."""
from app.camera.adapters import ICameraAdapter, Capabilities, CameraError

__all__ = ["ICameraAdapter", "Capabilities", "CameraError"]
```

- [ ] **Step 4: Run test to verify it passes**

Run: `python -m pytest services/core_service/tests/test_camera_contract.py -v`
Expected: PASS (3 passed)

- [ ] **Step 5: Commit**

```bash
git add services/core_service/app/camera/__init__.py services/core_service/app/camera/adapters.py services/core_service/tests/test_camera_contract.py
git commit -m "feat: add camera adapter ABC + Capabilities + CameraError"
```

---

### Task 2: FakeAdapter reference implementation

**Files:**
- Create: `services/core_service/app/camera/fake.py`
- Modify: `services/core_service/app/camera/__init__.py` (append FakeAdapter export)
- Test: `services/core_service/tests/test_camera_fake.py`

**Interfaces:**
- Consumes: `ICameraAdapter, Capabilities, CameraError` (Task 1, exact names)
- Produces: `FakeAdapter(available=True)` (Tasks 3-5 use; vendor adapters must match its observable behavior)

- [ ] **Step 1: Write the failing test**

```python
# services/core_service/tests/test_camera_fake.py
import os
import pytest
from app.camera.fake import FakeAdapter
from app.camera.adapters import CameraError


def test_detect_follows_available_flag():
    assert FakeAdapter(available=True).detect() is True
    assert FakeAdapter(available=False).detect() is False


def test_frame_is_jpeg_after_start(tmp_path):
    cam = FakeAdapter()
    cam.connect()
    cam.start_liveview()
    frame = cam.grab_frame()
    assert frame[:2] == b"\xff\xd8"
    cam.stop_liveview()
    with pytest.raises(CameraError):
        cam.grab_frame()


def test_capture_writes_file_with_md5(tmp_path):
    cam = FakeAdapter()
    cam.connect()
    dest = str(tmp_path / "Core01_1_000.00_2.60.jpg")
    r = cam.capture(dest)
    assert os.path.exists(dest) and r["path"] == dest
    assert len(r["md5"]) == 32 and r["bytes"] > 0


def test_settings_ok_and_capabilities_all_true():
    cam = FakeAdapter()
    assert cam.set_iso(1200) == {"ok": True}
    caps = cam.get_capabilities()
    assert (caps.supports_liveview, caps.supports_iso, caps.supports_focus, caps.supports_zoom, caps.supports_capture) == (True, True, True, True, True)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python -m pytest services/core_service/tests/test_camera_fake.py -v`
Expected: FAIL with "No module named 'app.camera.fake'"

- [ ] **Step 3: Write minimal implementation**

```python
# services/core_service/app/camera/fake.py
"""FakeAdapter: synthetic camera proving the ICameraAdapter contract without hardware."""
import hashlib
import io
from PIL import Image, ImageDraw
from app.camera.adapters import ICameraAdapter, Capabilities, CameraError


class FakeAdapter(ICameraAdapter):
    def __init__(self, available: bool = True):
        self._available = available
        self._connected = False
        self._live = False
        self._frames = 0

    @property
    def name(self) -> str:
        return "fake"

    def detect(self) -> bool:
        return self._available

    def connect(self) -> None:
        if not self._available:
            raise CameraError("camera not detected: check USB connection and retry")
        self._connected = True

    def disconnect(self) -> None:
        self._connected = False
        self._live = False

    def is_connected(self) -> bool:
        return self._connected

    def get_capabilities(self) -> Capabilities:
        return Capabilities(supports_liveview=True, supports_iso=True, supports_focus=True, supports_zoom=True, supports_capture=True)

    def start_liveview(self) -> None:
        if not self._connected:
            raise CameraError("cannot start live view: camera not connected")
        self._live = True

    def stop_liveview(self) -> None:
        self._live = False

    def liveview_running(self) -> bool:
        return self._live and self._connected

    def _render(self, w: int, h: int) -> bytes:
        self._frames += 1
        img = Image.new("RGB", (w, h), (30 + self._frames % 40, 60, 90))
        ImageDraw.Draw(img).text((20, 20), f"FAKE frame {self._frames}")
        buf = io.BytesIO()
        img.save(buf, "JPEG", quality=85)
        return buf.getvalue()

    def grab_frame(self) -> bytes:
        if not self.liveview_running():
            raise CameraError("live view not running: call start first")
        return self._render(640, 480)

    def capture(self, dest_path: str) -> dict:
        if not self._connected:
            raise CameraError("capture blocked: camera not ready")
        data = self._render(800, 600)
        with open(dest_path, "wb") as f:
            f.write(data)
        return {"path": dest_path, "md5": hashlib.md5(data).hexdigest(), "bytes": len(data)}

    def set_iso(self, value) -> dict:
        return {"ok": True}

    def set_focus(self, value) -> dict:
        return {"ok": True}

    def set_zoom(self, value) -> dict:
        return {"ok": True}
```

Append to `services/core_service/app/camera/__init__.py`:

```python
from app.camera.fake import FakeAdapter

__all__ = ["ICameraAdapter", "Capabilities", "CameraError", "FakeAdapter"]
```

(replace the existing `__all__` line; keep the first import line)

- [ ] **Step 4: Run test to verify it passes**

Run: `python -m pytest services/core_service/tests/test_camera_fake.py -v`
Expected: PASS (4 passed)

- [ ] **Step 5: Commit**

```bash
git add services/core_service/app/camera/fake.py services/core_service/app/camera/__init__.py services/core_service/tests/test_camera_fake.py
git commit -m "feat: add FakeAdapter synthetic camera proving adapter contract"
```

---

### Task 3: CameraManager (auto-detect, status mapping, ready-guard)

**Files:**
- Create: `services/core_service/app/camera/manager.py`
- Modify: `services/core_service/app/camera/__init__.py` (append manager exports)
- Test: `services/core_service/tests/test_camera_manager.py`

**Interfaces:**
- Consumes: `ICameraAdapter, CameraError` (Task 1); `FakeAdapter` (Task 2)
- Produces: `STATUS_READY="Connected/Ready", STATUS_DOWN="Not Connected", STATUS_ERROR="Error"`, `CameraManager(adapters)` with `detect()/status()/active/require_ready()/connect_active()/disconnect_all()` (Task 4 endpoints use exact names/shapes)

- [ ] **Step 1: Write the failing test**

```python
# services/core_service/tests/test_camera_manager.py
import pytest
from app.camera.fake import FakeAdapter
from app.camera.manager import CameraManager, STATUS_READY, STATUS_DOWN, STATUS_ERROR
from app.camera.adapters import CameraError


def test_detect_picks_first_available():
    m = CameraManager([FakeAdapter(available=False), FakeAdapter(available=True)])
    s = m.detect()
    assert s["status"] == STATUS_READY and s["adapter"] == "fake"


def test_no_camera_gives_not_connected():
    m = CameraManager([FakeAdapter(available=False)])
    assert m.detect()["status"] == STATUS_DOWN


def test_disconnect_returns_to_not_connected():
    m = CameraManager([FakeAdapter()])
    m.detect()
    m.disconnect_all()
    assert m.status()["status"] == STATUS_DOWN


def test_require_ready_blocks_capture_without_camera():
    m = CameraManager([FakeAdapter(available=False)])
    m.detect()
    with pytest.raises(CameraError):
        m.require_ready()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python -m pytest services/core_service/tests/test_camera_manager.py -v`
Expected: FAIL with "No module named 'app.camera.manager'"

- [ ] **Step 3: Write minimal implementation**

```python
# services/core_service/app/camera/manager.py
"""CameraManager: auto-detect order, single active adapter, PRD 6.2 status mapping."""
from app.camera.adapters import ICameraAdapter, CameraError

STATUS_READY = "Connected/Ready"
STATUS_DOWN = "Not Connected"
STATUS_ERROR = "Error"


class CameraManager:
    def __init__(self, adapters: list):
        self._adapters: list = list(adapters)
        self._active: ICameraAdapter | None = None
        self._detail: str = "no camera detected yet"

    @property
    def active(self):
        return self._active

    def detect(self) -> dict:
        for adapter in self._adapters:
            try:
                if adapter.detect():
                    adapter.connect()
                    self._active = adapter
                    self._detail = f"{adapter.name} connected"
                    return self.status()
            except CameraError as e:
                self._detail = str(e)
        self._active = None
        if "no camera detected yet" not in self._detail:
            self._detail = "no camera detected: check USB connection and retry"
        return self.status()

    def status(self) -> dict:
        if self._active is not None and self._active.is_connected():
            return {"status": STATUS_READY, "adapter": self._active.name, "detail": self._detail}
        if self._detail and "not detected" not in self._detail and "yet" not in self._detail and "disconnected" not in self._detail:
            return {"status": STATUS_ERROR, "adapter": None, "detail": self._detail}
        return {"status": STATUS_DOWN, "adapter": None, "detail": self._detail}

    def require_ready(self) -> ICameraAdapter:
        if self._active is None or not self._active.is_connected():
            raise CameraError("capture blocked: camera not ready")
        return self._active

    def connect_active(self) -> dict:
        return self.detect()

    def disconnect_all(self) -> dict:
        for adapter in self._adapters:
            adapter.disconnect()
        self._active = None
        self._detail = "disconnected by operator"
        return self.status()
```

Append to `services/core_service/app/camera/__init__.py`:

```python
from app.camera.manager import CameraManager, STATUS_READY, STATUS_DOWN, STATUS_ERROR

__all__ = ["ICameraAdapter", "Capabilities", "CameraError", "FakeAdapter", "CameraManager", "STATUS_READY", "STATUS_DOWN", "STATUS_ERROR"]
```

(replace the existing `__all__` line; keep earlier import lines)

- [ ] **Step 4: Run test to verify it passes**

Run: `python -m pytest services/core_service/tests/test_camera_manager.py -v`
Expected: PASS (4 passed)

- [ ] **Step 5: Commit**

```bash
git add services/core_service/app/camera/manager.py services/core_service/app/camera/__init__.py services/core_service/tests/test_camera_manager.py
git commit -m "feat: add CameraManager auto-detect + PRD-6.2 status mapping"
```

---

### Task 4: Camera localhost endpoints + MJPEG live view

**Files:**
- Modify: `services/core_service/app/main.py` (full replacement below; Plan 1 endpoints byte-identical)
- Test: `services/core_service/tests/test_camera.py`

**Interfaces:**
- Consumes: `CameraManager, FakeAdapter, STATUS_*` (Tasks 2-3); `validate_interval, get_job` (Plan 1, unchanged)
- Produces: camera endpoints + module singleton `camera_manager` (Task 5 uses `camera_manager.require_ready()`)

- [ ] **Step 1: Write the failing test**

```python
# services/core_service/tests/test_camera.py
from fastapi.testclient import TestClient
from app.main import create_app


def test_connect_and_status_ready():
    c = TestClient(create_app())
    r = c.post("/camera/connect")
    assert r.status_code == 200
    body = r.json()
    assert body["status"] == "Connected/Ready" and body["adapter"] == "fake"


def test_capabilities_and_settings():
    c = TestClient(create_app())
    c.post("/camera/connect")
    caps = c.get("/camera/capabilities").json()
    assert caps["supports_capture"] is True
    r = c.post("/camera/settings", json={"iso": 1200, "zoom": 2}).json()
    assert r["iso"] == {"ok": True} and r["zoom"] == {"ok": True}
    assert "focus" not in r


def test_frame_and_mjpeg_need_running_liveview():
    c = TestClient(create_app())
    c.post("/camera/connect")
    assert c.get("/camera/frame").status_code == 409
    assert c.post("/camera/liveview/start").json() == {"ok": True}
    frame = c.get("/camera/frame")
    assert frame.status_code == 200 and frame.content[:2] == b"\xff\xd8"
    with c.stream("GET", "/camera/liveview.mjpg") as r:
        assert r.status_code == 200
        assert r.headers["content-type"].startswith("multipart/x-mixed-replace")
        chunk = next(r.iter_bytes())
        assert b"\xff\xd8" in chunk
    assert c.post("/camera/liveview/stop").json() == {"ok": True}


def test_disconnect_returns_not_connected():
    c = TestClient(create_app())
    c.post("/camera/connect")
    body = c.post("/camera/disconnect").json()
    assert body["status"] == "Not Connected"
    c.post("/camera/connect")
```

NOTE: last line reconnects so Task 5's file (runs after alphabetically: test_camera.py < test_capture.py) starts from connected state.

- [ ] **Step 2: Run test to verify it fails**

Run: `python -m pytest services/core_service/tests/test_camera.py -v`
Expected: FAIL with "No route" / 404 on `/camera/connect` (main.py has no camera routes yet)

- [ ] **Step 3: Write minimal implementation**

Replace `services/core_service/app/main.py` with this full content (Plan 1 section byte-identical):

```python
# services/core_service/app/main.py
"""Localhost API skeleton. Bind 127.0.0.1 only at runtime; no network exposure."""
from dataclasses import asdict
from fastapi import FastAPI
from fastapi.responses import JSONResponse, Response, StreamingResponse
from app.camera.adapters import CameraError
from app.camera.fake import FakeAdapter
from app.camera.manager import CameraManager
from app.jobs import get_job
from app.validation import validate_interval

VERSION = "0.1.0"

camera_manager = CameraManager([FakeAdapter()])


def _mjpeg(manager: CameraManager):
    while manager.active is not None and manager.active.liveview_running():
        frame = manager.active.grab_frame()
        yield b"--frame\r\nContent-Type: image/jpeg\r\n\r\n" + frame + b"\r\n"


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

    @app.get("/camera/status")
    def camera_status() -> dict:
        return camera_manager.status()

    @app.post("/camera/connect")
    def camera_connect() -> dict:
        try:
            return camera_manager.connect_active()
        except CameraError as e:
            return {"status": "Error", "adapter": None, "detail": str(e)}

    @app.post("/camera/disconnect")
    def camera_disconnect() -> dict:
        return camera_manager.disconnect_all()

    @app.get("/camera/capabilities")
    def camera_capabilities() -> dict:
        if camera_manager.active is None:
            return {"adapter": None, "supports_liveview": False, "supports_iso": False, "supports_focus": False, "supports_zoom": False, "supports_capture": False}
        caps = asdict(camera_manager.active.get_capabilities())
        caps["adapter"] = camera_manager.active.name
        return caps

    @app.post("/camera/settings")
    def camera_settings(payload: dict) -> dict:
        out: dict = {}
        if camera_manager.active is None:
            for key in ("iso", "focus", "zoom"):
                if key in payload:
                    out[key] = {"ok": False, "reason": "no camera"}
            return out
        adapter = camera_manager.active
        if "iso" in payload:
            out["iso"] = adapter.set_iso(payload["iso"])
        if "focus" in payload:
            out["focus"] = adapter.set_focus(payload["focus"])
        if "zoom" in payload:
            out["zoom"] = adapter.set_zoom(payload["zoom"])
        return out

    @app.post("/camera/liveview/start")
    def liveview_start() -> dict:
        try:
            camera_manager.require_ready().start_liveview()
            return {"ok": True}
        except CameraError as e:
            return {"ok": False, "error": str(e)}

    @app.post("/camera/liveview/stop")
    def liveview_stop() -> dict:
        if camera_manager.active is not None:
            camera_manager.active.stop_liveview()
        return {"ok": True}

    @app.get("/camera/frame")
    def camera_frame():
        try:
            frame = camera_manager.require_ready().grab_frame()
            return Response(content=frame, media_type="image/jpeg")
        except CameraError as e:
            return JSONResponse(status_code=409, content={"error": str(e)})

    @app.get("/camera/liveview.mjpg")
    def camera_mjpeg():
        if camera_manager.active is None or not camera_manager.active.liveview_running():
            return JSONResponse(status_code=409, content={"error": "live view not running: call start first"})
        return StreamingResponse(_mjpeg(camera_manager), media_type="multipart/x-mixed-replace; boundary=frame")

    return app


app = create_app()
```

- [ ] **Step 4: Run test to verify it passes**

Run: `python -m pytest services/core_service/tests/test_camera.py -v`
Expected: PASS (4 passed)

- [ ] **Step 5: Commit**

```bash
git add services/core_service/app/main.py services/core_service/tests/test_camera.py
git commit -m "feat: add camera localhost endpoints + MJPEG live view"
```

---

### Task 5: POST /captures job endpoint (valid → done + file; invalid/disconnected → job error)

**Files:**
- Modify: `services/core_service/app/main.py` (append `/captures` route inside `create_app`, before `return app`; add imports `os`, `create_job/finish_job/fail_job`, `validate_filename`, `md5_file`)
- Test: `services/core_service/tests/test_capture.py`

**Interfaces:**
- Consumes: `camera_manager.require_ready()` (Task 4), `create_job/finish_job/fail_job/get_job` (Plan 1 + Task 4 file), `validate_filename` (Plan 1 Task 2), `md5_file` (Plan 1 Task 4)
- Produces: `POST /captures {filename, box, out_dir} -> {job_id}` (Flutter Plan 3 consumes; `GET /jobs/{id}` result `{raw_path, md5, filename}`)

- [ ] **Step 1: Write the failing test**

```python
# services/core_service/tests/test_capture.py
import os
from fastapi.testclient import TestClient
from app.main import create_app


def _job(c, job_id):
    return c.get(f"/jobs/{job_id}").json()


def test_capture_valid_produces_raw_and_md5(tmp_path):
    c = TestClient(create_app())
    c.post("/camera/connect")
    out = str(tmp_path / "tray")
    r = c.post("/captures", json={"filename": "Core01_1_000.00_2.60.jpg", "box": [10, 20], "out_dir": out}).json()
    job = _job(c, r["job_id"])
    assert job["status"] == "done"
    assert os.path.exists(job["result"]["raw_path"])
    assert len(job["result"]["md5"]) == 32


def test_capture_invalid_filename_gives_job_error(tmp_path):
    c = TestClient(create_app())
    r = c.post("/captures", json={"filename": "random.jpg", "box": [0, 0], "out_dir": str(tmp_path)}).json()
    job = _job(c, r["job_id"])
    assert job["status"] == "error"


def test_capture_blocked_when_disconnected(tmp_path):
    c = TestClient(create_app())
    c.post("/camera/disconnect")
    r = c.post("/captures", json={"filename": "Core01_1_000.00_2.60.jpg", "box": [0, 0], "out_dir": str(tmp_path)}).json()
    assert _job(c, r["job_id"])["status"] == "error"
    c.post("/camera/connect")
```

NOTE: last line reconnects to leave global singleton connected for any later suite runs.

- [ ] **Step 2: Run test to verify it fails**

Run: `python -m pytest services/core_service/tests/test_capture.py -v`
Expected: FAIL with 404 on `/captures` (route does not exist yet)

- [ ] **Step 3: Write minimal implementation**

In `services/core_service/app/main.py`:
1. Extend the jobs import line to: `from app.jobs import create_job, finish_job, fail_job, get_job`
2. Add imports: `import os`, `from app.filenames import validate_filename`, `from app.storage import md5_file`
3. Insert this route inside `create_app`, before `return app` (final version — use exactly this):

```python
    @app.post("/captures")
    def captures(payload: dict) -> dict:
        job = create_job("capture")
        check = validate_filename(str(payload.get("filename", "")))
        if not check["valid"]:
            fail_job(job["id"], check.get("warning", "invalid filename"))
            return {"job_id": job["id"]}
        try:
            adapter = camera_manager.require_ready()
        except CameraError as e:
            fail_job(job["id"], str(e))
            return {"job_id": job["id"]}
        try:
            out_dir = str(payload.get("out_dir", ""))
            os.makedirs(out_dir, exist_ok=True)
            raw_path = os.path.join(out_dir, str(payload["filename"]))
            adapter.capture(raw_path)
            finish_job(job["id"], {"raw_path": raw_path, "md5": md5_file(raw_path), "filename": str(payload["filename"])})
        except (CameraError, OSError) as e:
            fail_job(job["id"], str(e))
        return {"job_id": job["id"]}
```

(`box` payload accepted and ignored for now — framing overlay lives in Flutter per spec; crop anchor flows in at processing time.)

- [ ] **Step 4: Run test to verify it passes**

Run: `python -m pytest services/core_service/tests/test_capture.py -v`
Expected: PASS (3 passed)

- [ ] **Step 5: Commit**

```bash
git add services/core_service/app/main.py services/core_service/tests/test_capture.py
git commit -m "feat: add POST /captures job endpoint with ready-guard"
```

---

### Task 6: Full suite gate + push

**Files:**
- Modify: none (verification only)

- [ ] **Step 1: Run full suite**

Run: `$env:PYTHONPATH='services/core_service'; python -m pytest services/core_service/tests -v`
Expected: PASS (all Plan 1 + Plan 2 tests, 12 + 3 + 4 + 4 + 4 + 3 = 30 tests)

- [ ] **Step 2: Push**

```bash
git push origin main
```
Expected: up-to-date remote `main`

## Self-Review

1. **Spec coverage:** §6.1 connect/detect/retry → Tasks 3-4; §6.2 Connected/Ready|Not Connected|Error → Task 3 constants reused in Task 4; §6.3 Live View → Task 4 start/stop/frame/mjpg; §6.4 capability-based ISO/Focus/Zoom + no-crash → Tasks 1-2 + 4 settings; capture→review→save flow start (capture job) → Task 5; §10/§11 retake/save + §12/13 processing chain = later plans (processing reuses Task 5 raw_path + Plan 1 imaging).
2. **Placeholder scan:** no TBD/TODO/fill-in; every step has literal code, literal run commands, literal commit messages. Task 5 NOTE lines are explicit keep/delete instructions, not placeholders.
3. **Type consistency:** `STATUS_*` exact strings defined once (manager.py) reused in tests; `ICameraAdapter` method set identical in adapters.py/fake.py/contract test Dummy; `create_job/finish_job/fail_job/get_job` keys `{id,kind,status,progress,result,error}` match Plan 1; `validate_filename → {valid,captureEnabled,warning,parsed}` keys reused in Task 5; `md5_file(path)->str`; `crop` untouched. Test execution order dependency (camera connect state) made explicit via reconnect NOTEs in Tasks 4-5.
