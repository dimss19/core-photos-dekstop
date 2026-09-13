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
