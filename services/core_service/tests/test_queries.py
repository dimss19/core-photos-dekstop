import os
import tempfile

import pytest

from app.db import Database
from app.db.schema import init_schema
from app.db import queries as q


@pytest.fixture()
def db():
    with tempfile.TemporaryDirectory() as tmp:
        d = Database(os.path.join(tmp, "t.db"))
        d.connect()
        init_schema(d)
        yield d
        d.close()


def test_session_crud(db):
    s = q.create_session(db, "2026-09-13", "Dimas", "SiteA")
    assert s["id"] == "s1" and s["operator"] == "Dimas"
    assert [x["id"] for x in q.list_sessions(db)] == ["s1"]
    assert q.get_session(db, "s9") is None


def test_tray_and_validation_flag(db):
    s = q.create_session(db, "2026-09-13", "Dimas", "SiteA")
    t = q.create_tray(db, s["id"], "Core01", "1", 0.0, 2.6, rows=3, comments="ok")
    assert t["id"] == "t1" and t["validation"] is None
    q.set_tray_validation(db, "t1", "VALID")
    assert q.get_tray(db, "t1")["validation"] == "VALID"


def test_photo_and_filtered_list(db):
    s = q.create_session(db, "2026-09-13", "Dimas", "SiteA")
    t = q.create_tray(db, s["id"], "Core01", "1", 0.0, 2.6)
    p = q.create_photo(db, t["id"], "Core01_1_000.00_2.60.jpg", "/r.jpg", "/j.jpg", "/t.jpg", "abc")
    assert p["id"] == "p1"
    assert len(q.list_photos(db)) == 1
    assert len(q.list_photos(db, hole_id="Core01")) == 1
    assert q.list_photos(db, hole_id="Other") == []
    assert len(q.list_photos(db, session_id=s["id"])) == 1


def test_transfer_lifecycle(db):
    s = q.create_session(db, "2026-09-13", "Dimas", "SiteA")
    x = q.create_transfer(db, s["id"], '["s1"]', "D:\\srv")
    assert x["status"] == "queued" and x["progress"] == 0
    q.update_transfer(db, x["id"], "success", 100)
    done = q.get_transfer(db, x["id"])
    assert done["status"] == "success" and done["validated_at"] is not None
