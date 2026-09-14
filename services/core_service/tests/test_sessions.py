import pytest
from fastapi.testclient import TestClient
from app import main as m


@pytest.fixture()
def api(tmp_path):
    m.init_db(str(tmp_path / "t.db"))
    m._wipe_db()
    m._active_session_id = None
    yield TestClient(m.create_app())


def test_create_lists_and_activates(api):
    s1 = api.post("/sessions", json={"date": "2026-09-13", "operator": "Dimas", "site": "SiteA"}).json()["session"]
    assert s1["id"] == "s1" and s1["operator"] == "Dimas"
    api.post("/sessions", json={"date": "2026-09-13", "operator": "Ricky", "site": "SiteA"})
    assert api.get("/sessions").json()["sessions"][0]["id"] == "s1"
    assert api.get("/sessions/active").json()["active"]["id"] == "s2"
    assert api.post("/sessions/s1/activate").json()["active"]["id"] == "s1"


def test_activate_unknown_is_404(api):
    assert api.post("/sessions/nope/activate").status_code == 404
