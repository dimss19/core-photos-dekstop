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
