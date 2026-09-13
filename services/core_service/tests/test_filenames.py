from app.filenames import parse_filename, validate_filename


def test_parse_valid_filename():
    r = parse_filename("Core01_1_000.00_2.60.jpg")
    assert r == {"hole_id": "Core01", "tray_no": 1, "interval_from": 0.0, "interval_to": 2.6, "ext": "jpg"}


def test_reject_to_less_than_from():
    r = validate_filename("Core01_1_002.60_000.00.jpg")
    assert r["valid"] is False
    assert r["captureEnabled"] is False


def test_reject_bad_format():
    assert validate_filename("random.jpg")["valid"] is False
