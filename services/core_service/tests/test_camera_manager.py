import pytest
from app.camera.fake import FakeAdapter
from app.camera.manager import CameraManager, STATUS_READY, STATUS_DOWN, STATUS_ERROR
from app.camera.adapters import CameraError


def test_detect_picks_first_available():
    m = CameraManager([FakeAdapter(available=False), FakeAdapter(available=True)])
    s = m.detect()
    assert s["status"] == STATUS_READY and s["adapter"] == "fake"


def test_no_camera_gives_not_connected():
    m = CameraManager([FakeAdapter(available=False)])
    assert m.detect()["status"] == STATUS_DOWN


def test_disconnect_returns_to_not_connected():
    m = CameraManager([FakeAdapter()])
    m.detect()
    m.disconnect_all()
    assert m.status()["status"] == STATUS_DOWN


def test_require_ready_blocks_capture_without_camera():
    m = CameraManager([FakeAdapter(available=False)])
    m.detect()
    with pytest.raises(CameraError):
        m.require_ready()
