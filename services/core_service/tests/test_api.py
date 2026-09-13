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
