# services/core_service/app/main.py
"""Localhost API skeleton. Bind 127.0.0.1 only at runtime; no network exposure."""
import logging
import os
import re
import shutil
import time
from dataclasses import asdict
from fastapi import FastAPI
from fastapi.responses import FileResponse, JSONResponse, Response, StreamingResponse
from app.camera.adapters import CameraError
from app.camera.fake import FakeAdapter
from app.camera.manager import CameraManager
from app.db import Database
from app.db.schema import init_schema
from app.db import queries as q
from app.filenames import validate_filename
from app.imaging import crop_tray, resolve_box
from app.jobs import create_job, finish_job, fail_job, get_job
from app.storage import atomic_write_json, build_sidecar, md5_file, resolve_tray_dir
from app.validation import validate_interval, validate_tray

VERSION = "0.1.0"

logger = logging.getLogger("corephoto")
if not logger.handlers:
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s: %(message)s")
    try:
        _logdir = os.path.join(os.environ.get("LOCALAPPDATA") or os.path.expanduser("~"), "CorePhoto")
        os.makedirs(_logdir, exist_ok=True)
        logger.addHandler(logging.FileHandler(os.path.join(_logdir, "corephoto.log"), encoding="utf-8"))
    except OSError:
        pass

camera_manager = CameraManager([FakeAdapter()])

_db: Database | None = None
_active_session_id: str | None = None
_capture_ctx: dict = {}
_transfer_ctx: dict = {}


def _default_db_path() -> str:
    base = os.environ.get("LOCALAPPDATA") or os.path.expanduser("~")
    return os.path.join(base, "CorePhoto", "data.db")


def init_db(path: str | None = None) -> Database:
    global _db
    p = path or os.environ.get("COREPHOTO_DB") or _default_db_path()
    os.makedirs(os.path.dirname(p), exist_ok=True)
    _db = Database(p)
    _db.connect()
    init_schema(_db)
    return _db


def _wipe_db() -> None:
    """Test helper: empty all domain tables (keeps schema)."""
    with _db.transaction() as cur:
        for t in ("photos", "trays", "transfers", "sessions"):
            cur.execute(f"DELETE FROM {t}")


init_db()


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
            status = camera_manager.connect_active()
            logger.info("camera connect: %s", status.get("status"))
            return status
        except CameraError as e:
            logger.warning("camera connect failed: %s", e)
            return {"status": "Error", "adapter": None, "detail": str(e)}

    @app.post("/camera/disconnect")
    def camera_disconnect() -> dict:
        status = camera_manager.disconnect_all()
        logger.info("camera disconnect")
        return status

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
            tray = None
            if payload.get("tray_id"):
                tray = q.get_tray(_db, str(payload["tray_id"]))
                if tray is None:
                    fail_job(job["id"], "unknown tray")
                    return {"job_id": job["id"]}
                session = q.get_session(_db, tray["session_id"]) or {}
                label = f"{tray['hole_id']}_{tray['tray_id']}_{tray['interval_from']}-{tray['interval_to']}"
                label = re.sub(r'[\\/:*?"<>|]+', '_', label)
                # PRD §17.1: folder versi otomatis (_v2, _v3), file lama tak tertimpa.
                out_dir = resolve_tray_dir(out_dir or ".", str(session.get("date", "")), tray["hole_id"], label)
            os.makedirs(out_dir, exist_ok=True)
            raw_path = os.path.join(out_dir, str(payload["filename"]))
            adapter.capture(raw_path)
            if payload.get("tray_id"):
                _capture_ctx[job["id"]] = {"tray_id": str(payload["tray_id"]), "box": payload.get("box", [0, 0])}
            logger.info("capture done: %s", raw_path)
            finish_job(job["id"], {"raw_path": raw_path, "md5": md5_file(raw_path), "filename": str(payload["filename"])})
        except (CameraError, OSError) as e:
            logger.warning("capture failed: %s", e)
            fail_job(job["id"], str(e))
        return {"job_id": job["id"]}

    @app.post("/captures/{jid}/retake")
    def captures_retake(jid: str, payload: dict) -> dict:
        prev = _capture_ctx.get(jid, {})
        tray_id = str(payload.get("tray_id", prev.get("tray_id", "")))
        box = payload.get("box", prev.get("box", [0, 0]))
        job = create_job("capture")
        try:
            adapter = camera_manager.require_ready()
        except CameraError as e:
            fail_job(job["id"], str(e))
            return {"job_id": job["id"]}
        try:
            out_dir = str(payload.get("out_dir", ""))
            filename = str(payload.get("filename", ""))
            if not filename:
                fail_job(job["id"], "filename required for retake")
                return {"job_id": job["id"]}
            os.makedirs(out_dir, exist_ok=True)
            raw_path = os.path.join(out_dir, filename)
            adapter.capture(raw_path)
            if tray_id:
                _capture_ctx[job["id"]] = {"tray_id": tray_id, "box": box}
            logger.info("retake done: %s", raw_path)
            finish_job(job["id"], {"raw_path": raw_path, "md5": md5_file(raw_path), "filename": filename})
        except (CameraError, OSError) as e:
            logger.warning("retake failed: %s", e)
            fail_job(job["id"], str(e))
        return {"job_id": job["id"]}

    @app.post("/trays", status_code=201)
    def create_tray(payload: dict) -> dict:
        check = validate_tray({
            "hole_id": payload.get("hole_id", ""),
            "tray_id": payload.get("tray_id", ""),
            "interval_from": payload.get("interval_from"),
            "interval_to": payload.get("interval_to"),
        })
        if not check["valid"]:
            return JSONResponse(status_code=422, content={"errors": check["errors"]})
        if not q.get_session(_db, str(payload.get("session_id", ""))):
            return JSONResponse(status_code=404, content={"error": "unknown session"})
        tray = q.create_tray(
            _db, str(payload.get("session_id")), str(payload.get("hole_id")), str(payload.get("tray_id")),
            float(payload.get("interval_from")), float(payload.get("interval_to")),
            int(payload.get("rows", 0)), payload.get("length"), payload.get("width"),
            str(payload.get("comments", "")),
        )
        return {"tray": tray}

    @app.post("/trays/validate")
    def validate_tray_record(payload: dict) -> dict:
        tray = q.get_tray(_db, str(payload.get("tray_id", "")))
        if tray is None:
            return JSONResponse(status_code=404, content={"error": "unknown tray"})
        file_ok, file_warning = True, ""
        cur = _db.cursor()
        cur.execute("SELECT filename FROM photos WHERE tray_id = ? ORDER BY rowid DESC LIMIT 1", (tray["id"],))
        row = cur.fetchone()
        if row is not None:
            fc = validate_filename(row[0])
            file_ok, file_warning = fc["valid"], fc.get("warning", "")
        check = validate_tray(tray)
        valid = check["valid"] and file_ok
        errors = dict(check.get("errors", {}))
        if not file_ok:
            errors["filename"] = file_warning
        status = "VALID" if valid else "INVALID"
        q.set_tray_validation(_db, tray["id"], status)
        return {"valid": valid, "status": status, "errors": errors}

    @app.post("/process")
    def process_capture(payload: dict) -> dict:
        job = create_job("process")
        raw_path = str(payload.get("raw_path", ""))
        tray = q.get_tray(_db, str(payload.get("tray_id", "")))
        if tray is None:
            fail_job(job["id"], "unknown tray")
            return {"job_id": job["id"]}
        if not os.path.exists(raw_path):
            fail_job(job["id"], f"RAW not readable: {raw_path}")
            return {"job_id": job["id"]}
        filename = os.path.basename(raw_path)
        fc = validate_filename(filename)
        if not fc["valid"]:
            fail_job(job["id"], fc.get("warning", "invalid filename"))
            return {"job_id": job["id"]}
        try:
            from PIL import Image
            with Image.open(raw_path) as _im:
                _w, _h = _im.size
            box = resolve_box(payload.get("box", [0, 0]), _w, _h)
            stem, _ = os.path.splitext(raw_path)
            jpg_path, thumb_path, sidecar_path = stem + "_display.jpg", stem + "_thumb.jpg", stem + ".json"
            crop = crop_tray(raw_path, jpg_path, thumb_path, box)
            md5 = md5_file(raw_path)
            session = q.get_session(_db, tray["session_id"]) or {}
            sidecar = build_sidecar(
                tray["hole_id"], tray["tray_id"], tray["interval_from"], tray["interval_to"],
                filename, md5, session,
                {"path": raw_path, "comments": tray.get("comments", ""),
                 "timestamp": time.time(), "rows": tray.get("rows", 0),
                 "length": tray.get("length"), "width": tray.get("width"), "crop": crop},
            )
            atomic_write_json(sidecar_path, sidecar)
            photo = q.create_photo(_db, tray["id"], filename, raw_path, jpg_path, thumb_path, md5)
            logger.info("process done: %s -> %s", raw_path, jpg_path)
            finish_job(job["id"], {"photo_id": photo["id"], "jpg_path": jpg_path,
                                   "thumb_path": thumb_path, "md5": md5})
        except OSError as e:
            logger.warning("process failed: %s", e)
            fail_job(job["id"], str(e))
        return {"job_id": job["id"]}

    @app.get("/photos")
    def list_photos_endpoint(drillhole: str | None = None, session_id: str | None = None) -> dict:
        return {"photos": q.list_photos(_db, hole_id=drillhole, session_id=session_id)}

    @app.get("/photos/{pid}/file")
    def photo_file(pid: str, variant: str = "jpg"):
        photo = q.get_photo(_db, pid)
        if photo is None:
            return JSONResponse(status_code=404, content={"error": "unknown photo"})
        key = {"raw": "raw_path", "jpg": "jpg_path", "thumb": "thumb_path"}.get(variant)
        if key is None or not photo.get(key) or not os.path.exists(photo[key]):
            return JSONResponse(status_code=404, content={"error": f"variant unavailable: {variant}"})
        return FileResponse(photo[key], media_type="image/jpeg")

    @app.post("/transfer/check")
    def transfer_check(payload: dict) -> dict:
        dest = payload.get("destination", {}) if isinstance(payload, dict) else {}
        ok, detail = _check_destination(dest)
        return {"reachable": ok, "detail": detail}

    @app.post("/transfer")
    def transfer_start(payload: dict) -> dict:
        sids = payload.get("session_ids", []) if isinstance(payload, dict) else []
        dest = payload.get("destination", {}) if isinstance(payload, dict) else {}
        ok, detail = _check_destination(dest)
        xid = q.create_transfer(_db, ",".join(sids), "", dest.get("path", ""))["id"]
        job = create_job("transfer")
        _transfer_ctx[job["id"]] = {"session_ids": sids, "destination": dest, "xid": xid}
        if not ok:
            q.update_transfer(_db, xid, "error", 0, detail)
            fail_job(job["id"], detail)
            return {"job_id": job["id"]}
        _run_transfer(job["id"], sids, dest, xid)
        return {"job_id": job["id"]}

    @app.post("/transfer/{jid}/retry")
    def transfer_retry(jid: str) -> dict:
        ctx = _transfer_ctx.get(jid)
        if ctx is None:
            return JSONResponse(status_code=404, content={"error": f"unknown transfer job {jid}"})
        job = create_job("transfer")
        _transfer_ctx[job["id"]] = ctx
        _run_transfer(job["id"], ctx["session_ids"], ctx["destination"], ctx["xid"])
        return {"job_id": job["id"]}

    @app.post("/sessions", status_code=201)
    def create_session(payload: dict) -> dict:
        global _active_session_id
        session = q.create_session(_db, str(payload.get("date", "")), str(payload.get("operator", "")),
                                   str(payload.get("site", "")))
        _active_session_id = session["id"]
        logger.info("session created: %s", session["id"])
        return {"session": session}

    @app.get("/sessions")
    def list_sessions() -> dict:
        return {"sessions": q.list_sessions(_db)}

    @app.post("/sessions/{sid}/activate")
    def activate_session(sid: str):
        global _active_session_id
        session = q.get_session(_db, sid)
        if session is None:
            return JSONResponse(status_code=404, content={"error": f"unknown session {sid}"})
        _active_session_id = sid
        return {"active": session}

    @app.get("/sessions/active")
    def active_session() -> dict:
        if _active_session_id is None:
            return {"active": None}
        return {"active": q.get_session(_db, _active_session_id)}

    return app


def _check_destination(dest: dict) -> tuple:
    if not isinstance(dest, dict) or dest.get("type", "folder") != "folder":
        return False, f"unsupported destination type {dest.get('type')!r}" if isinstance(dest, dict) else "invalid destination"
    path = str(dest.get("path", ""))
    if not path:
        return False, "destination path required"
    try:
        os.makedirs(path, exist_ok=True)
        probe = os.path.join(path, ".corephoto-write-test")
        with open(probe, "w") as f:
            f.write("ok")
        os.remove(probe)
        return True, "writable"
    except OSError as e:
        return False, str(e)


def _run_transfer(job_id: str, session_ids: list, dest: dict, xid: str) -> None:
    base = str(dest.get("path", ""))
    files: list = []
    for sid in session_ids:
        for p in q.list_photos(_db, session_id=sid):
            for key in ("raw_path", "jpg_path", "thumb_path"):
                if p.get(key):
                    files.append(p[key])
            stem, _ = os.path.splitext(p.get("raw_path", ""))
            if stem and os.path.exists(stem + ".json"):
                files.append(stem + ".json")
    total = max(1, len(files))
    copied, failed = [], []
    for i, src in enumerate(files, 1):
        try:
            rel = os.path.basename(src)
            target = os.path.join(base, rel)
            os.makedirs(base, exist_ok=True)
            shutil.copy2(src, target)
            if md5_file(target) != md5_file(src):
                raise OSError(f"checksum mismatch: {rel}")
            copied.append(rel)
        except OSError as e:
            failed.append(f"{os.path.basename(src)}: {e}")
        q.update_transfer(_db, xid, "running", int(i * 100 / total))
    if failed:
        q.update_transfer(_db, xid, "error", 100, "; ".join(failed))
        logger.warning("transfer %s failed: %s", job_id, "; ".join(failed))
        fail_job(job_id, "; ".join(failed))
    else:
        q.update_transfer(_db, xid, "success", 100)
        logger.info("transfer %s success: %d files", job_id, len(copied))
        # ponytail: sync copy in request; move to thread when RAW files grow large (contract unchanged)
        finish_job(job_id, {"copied": copied, "failed": failed, "dest": base})


app = create_app()
