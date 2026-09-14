import json
import logging
import os

import pytest
from fastapi.testclient import TestClient
from app import main as m
from app.storage import md5_file


@pytest.fixture()
def api(tmp_path):
    m.init_db(str(tmp_path / "t.db"))
    m._wipe_db()
    m._active_session_id = None
    m.camera_manager.detect()
    c = TestClient(m.create_app())
    c.out = str(tmp_path / "out")
    yield c


def _session(api):
    return api.post("/sessions", json={"date": "2026-09-13", "operator": "Dimas", "site": "SiteA"}).json()["session"]


def _tray(api, sid, frm=0.0, to=2.6):
    return api.post("/trays", json={"session_id": sid, "hole_id": "Core01", "tray_id": "1",
                                    "interval_from": frm, "interval_to": to, "rows": 3}).json()["tray"]


def _job(api, job_id):
    return api.get(f"/jobs/{job_id}").json()


def test_tray_create_and_validate(api):
    s = _session(api)
    bad = api.post("/trays", json={"session_id": s["id"], "hole_id": "Core01", "tray_id": "1",
                                   "interval_from": 20.0, "interval_to": 10.0})
    assert bad.status_code == 422 and "interval" in bad.json()["errors"]
    assert api.post("/trays", json={"session_id": "s9", "hole_id": "C", "tray_id": "1",
                                    "interval_from": 0, "interval_to": 1}).status_code == 404
    t = _tray(api, s["id"])
    assert t["id"] == "t1"
    v = api.post("/trays/validate", json={"tray_id": t["id"]}).json()
    assert v == {"valid": True, "status": "VALID", "errors": {}}
    assert api.post("/trays/validate", json={"tray_id": "t9"}).status_code == 404


def test_capture_process_chain(api):
    s = _session(api)
    t = _tray(api, s["id"])
    cap = api.post("/captures", json={"filename": "Core01_1_000.00_2.60.jpg", "tray_id": t["id"],
                                      "box": [10, 20], "out_dir": api.out}).json()
    job = _job(api, cap["job_id"])
    assert job["status"] == "done"
    raw = job["result"]["raw_path"]
    assert os.path.dirname(raw) != api.out and os.path.basename(raw) == "Core01_1_000.00_2.60.jpg"
    cap2 = api.post("/captures", json={"filename": "Core01_1_000.00_2.60.jpg", "tray_id": t["id"],
                                       "box": [0, 0], "out_dir": api.out}).json()["job_id"]
    raw2 = _job(api, cap2)["result"]["raw_path"]
    assert os.path.dirname(raw2) != os.path.dirname(raw) and raw2.endswith("_v2/Core01_1_000.00_2.60.jpg".replace("/", os.sep))
    bad_tray = api.post("/captures", json={"filename": "Core01_1_000.00_2.60.jpg", "tray_id": "t9",
                                           "box": [0, 0], "out_dir": api.out}).json()["job_id"]
    assert _job(api, bad_tray)["status"] == "error"
    proc = api.post("/process", json={"raw_path": raw, "tray_id": t["id"], "box": [10, 20]}).json()
    res = _job(api, proc["job_id"])
    assert res["status"] == "done"
    for key in ("jpg_path", "thumb_path"):
        assert os.path.exists(res["result"][key])
    stem, _ = os.path.splitext(raw)
    with open(stem + ".json") as f:
        sidecar = json.load(f)
    assert sidecar["hole_id"] == "Core01" and sidecar["md5"] == res["result"]["md5"]
    assert sidecar["operator"] == "Dimas" and sidecar["crop"]["size"] == [300, 200]
    photos = api.get("/photos", params={"drillhole": "Core01"}).json()["photos"]
    assert len(photos) == 1 and photos[0]["validation"] is None
    from app.filenames import validate_filename as _vf
    assert _vf(os.path.basename(res["result"]["jpg_path"]))["valid"] is True
    assert os.path.basename(res["result"]["jpg_path"]) == "Core01_1_000.00_2.60.jpg"
    thumb = api.get(f"/photos/{photos[0]['id']}/file", params={"variant": "thumb"})
    assert thumb.status_code == 200 and thumb.content[:2] == b"\xff\xd8"
    assert api.get("/photos/p9/file").status_code == 404
    v = api.post("/trays/validate", json={"tray_id": t["id"]}).json()
    assert v["status"] == "VALID"


def test_retake_reuses_tray(api):
    s = _session(api)
    t = _tray(api, s["id"])
    cap = api.post("/captures", json={"filename": "Core01_1_000.00_2.60.jpg", "tray_id": t["id"],
                                      "box": [0, 0], "out_dir": api.out}).json()["job_id"]
    assert _job(api, cap)["status"] == "done"
    re = api.post(f"/captures/{cap}/retake", json={"out_dir": api.out,
                                                  "filename": "Core01_1_000.00_2.60.jpg"}).json()["job_id"]
    job = _job(api, re)
    assert job["status"] == "done" and os.path.exists(job["result"]["raw_path"])


def test_transfer_flow_keeps_local(api):
    s = _session(api)
    t = _tray(api, s["id"])
    cap = api.post("/captures", json={"filename": "Core01_1_000.00_2.60.jpg", "tray_id": t["id"],
                                      "box": [0, 0], "out_dir": api.out}).json()["job_id"]
    raw = _job(api, cap)["result"]["raw_path"]
    api.post("/process", json={"raw_path": raw, "tray_id": t["id"], "box": [0, 0]})
    assert api.post("/transfer/check", json={"destination": {"type": "http"}}).json()["reachable"] is False
    bad = api.post("/transfer", json={"session_ids": [s["id"]], "destination": {"type": "http"}}).json()["job_id"]
    assert _job(api, bad)["status"] == "error"
    assert os.path.exists(raw)  # local aman
    dest = os.path.join(api.out, "srv")
    good = api.post("/transfer", json={"session_ids": [s["id"]],
                                       "destination": {"type": "folder", "path": dest}}).json()["job_id"]
    res = _job(api, good)
    assert res["status"] == "done" and not res["result"]["failed"]
    rawdir = os.path.dirname(raw)
    for f in res["result"]["copied"]:
        assert md5_file(os.path.join(dest, f)) == md5_file(os.path.join(rawdir, f))
    assert os.path.exists(raw)  # tetap ada setelah transfer
    retry = api.post(f"/transfer/{good}/retry").json()["job_id"]
    assert _job(api, retry)["status"] == "done"
    assert api.post("/transfer/job-0/retry").status_code == 404


def test_logging_records_camera_connect(api, caplog):
    with caplog.at_level(logging.INFO, logger="corephoto"):
        api.post("/camera/connect")
    assert any("camera connect" in r.message for r in caplog.records)
