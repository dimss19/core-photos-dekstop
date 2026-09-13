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
