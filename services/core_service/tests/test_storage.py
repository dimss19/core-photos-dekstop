from app.storage import md5_file, resolve_tray_dir


def test_md5_known_value(tmp_path):
    p = tmp_path / "a.bin"
    p.write_bytes(b"abc")
    assert md5_file(str(p)) == "900150983cd24fb0d6963f7d28e17f72"


def test_resolve_tray_dir_suffix_on_conflict(tmp_path):
    d1 = resolve_tray_dir(str(tmp_path), "S2026", "Core01", "T1_0-2.6")
    d2 = resolve_tray_dir(str(tmp_path), "S2026", "Core01", "T1_0-2.6")
    assert d1 != d2
    assert d2.endswith("_v2")
