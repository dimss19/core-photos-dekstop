import os
import pytest
from app.camera.fake import FakeAdapter
from app.camera.adapters import CameraError


def test_detect_follows_available_flag():
    assert FakeAdapter(available=True).detect() is True
    assert FakeAdapter(available=False).detect() is False


def test_frame_is_jpeg_after_start(tmp_path):
    cam = FakeAdapter()
    cam.connect()
    cam.start_liveview()
    frame = cam.grab_frame()
    assert frame[:2] == b"\xff\xd8"
    cam.stop_liveview()
    with pytest.raises(CameraError):
        cam.grab_frame()


def test_capture_writes_file_with_md5(tmp_path):
    cam = FakeAdapter()
    cam.connect()
    dest = str(tmp_path / "Core01_1_000.00_2.60.jpg")
    r = cam.capture(dest)
    assert os.path.exists(dest) and r["path"] == dest
    assert len(r["md5"]) == 32 and r["bytes"] > 0


def test_settings_ok_and_capabilities_all_true():
    cam = FakeAdapter()
    assert cam.set_iso(1200) == {"ok": True}
    caps = cam.get_capabilities()
    assert (caps.supports_liveview, caps.supports_iso, caps.supports_focus, caps.supports_zoom, caps.supports_capture) == (True, True, True, True, True)
