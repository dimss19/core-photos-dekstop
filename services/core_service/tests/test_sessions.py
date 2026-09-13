from fastapi.testclient import TestClient
from app.main import create_app


def test_create_lists_and_activates():
    c = TestClient(create_app())
    s1 = c.post("/sessions", json={"date": "2026-09-13", "operator": "Dimas", "site": "SiteA"}).json()["session"]
    assert s1["id"] == "s1" and s1["operator"] == "Dimas"
    s2 = c.post("/sessions", json={"date": "2026-09-13", "operator": "Ricky", "site": "SiteA"}).json()["session"]
    assert c.get("/sessions").json()["sessions"][0]["id"] == "s1"
    assert c.get("/sessions/active").json()["active"]["id"] == "s2"
    assert c.post("/sessions/s1/activate").json()["active"]["id"] == "s1"


def test_activate_unknown_is_404():
    c = TestClient(create_app())
    r = c.post("/sessions/nope/activate")
    assert r.status_code == 404
