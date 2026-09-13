from app.validation import validate_interval, validate_tray


def test_interval_invalid_disables_capture():
    r = validate_interval(20.0, 10.0)
    assert r == {"valid": False, "captureEnabled": False, "warning": "To < From"}


def test_interval_valid_enables_capture():
    r = validate_interval(10.0, 20.0)
    assert r["valid"] is True and r["captureEnabled"] is True


def test_tray_requires_hole_and_tray():
    r = validate_tray({"hole_id": "", "tray_id": "", "interval_from": 0.0, "interval_to": 1.0})
    assert r["valid"] is False
    assert "hole_id" in r["errors"]
