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
from app.filenames import validate_filename
from app.jobs import create_job, finish_job, fail_job, get_job
from app.storage import md5_file
from app.validation import validate_interval

VERSION = "0.1.0"

camera_manager = CameraManager([FakeAdapter()])

_sessions: dict = {}
_active_session_id: str | None = None


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

    @app.post("/sessions", status_code=201)
    def create_session(payload: dict) -> dict:
        global _active_session_id
        sid = f"s{len(_sessions) + 1}"
        session = {"id": sid, "date": str(payload.get("date", "")), "operator": str(payload.get("operator", "")), "site": str(payload.get("site", "")), "created_at": time.time()}
        _sessions[sid] = session
        _active_session_id = sid
        return {"session": session}

    @app.get("/sessions")
    def list_sessions() -> dict:
        return {"sessions": list(_sessions.values())}

    @app.post("/sessions/{sid}/activate")
    def activate_session(sid: str):
        global _active_session_id
        if sid not in _sessions:
            return JSONResponse(status_code=404, content={"error": f"unknown session {sid}"})
        _active_session_id = sid
        return {"active": _sessions[sid]}

    @app.get("/sessions/active")
    def active_session() -> dict:
        return {"active": _sessions.get(_active_session_id)}

    return app


app = create_app()
