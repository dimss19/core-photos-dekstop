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
    from app.main import _mjpeg, camera_manager
    gen = _mjpeg(camera_manager)
    first = next(gen)
    assert first.startswith(b"--frame\r\nContent-Type: image/jpeg\r\n\r\n") and b"\xff\xd8" in first
    second = next(gen)
    assert b"\xff\xd8" in second
    assert c.post("/camera/liveview/stop").json() == {"ok": True}
    assert list(gen) == []
    assert c.get("/camera/liveview.mjpg").status_code == 409


def test_disconnect_returns_not_connected():
    c = TestClient(create_app())
    c.post("/camera/connect")
    body = c.post("/camera/disconnect").json()
    assert body["status"] == "Not Connected"
    c.post("/camera/connect")
