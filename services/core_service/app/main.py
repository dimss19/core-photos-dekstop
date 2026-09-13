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
