import pytest
from app.camera.adapters import ICameraAdapter, Capabilities, CameraError


def test_abc_cannot_instantiate():
    with pytest.raises(TypeError):
        ICameraAdapter()


def test_capabilities_defaults_all_false():
    c = Capabilities()
    assert (c.supports_liveview, c.supports_iso, c.supports_focus, c.supports_zoom, c.supports_capture) == (False, False, False, False, False)


def test_dummy_subclass_satisfies_contract():
    class Dummy(ICameraAdapter):
        @property
        def name(self): return "dummy"
        def detect(self): return True
        def connect(self): pass
        def disconnect(self): pass
        def is_connected(self): return True
        def get_capabilities(self): return Capabilities(supports_capture=True)
        def start_liveview(self): pass
        def stop_liveview(self): pass
        def liveview_running(self): return False
        def grab_frame(self): return b"JPEG"
        def capture(self, dest_path): return {"path": dest_path, "md5": "x", "bytes": 0}
        def set_iso(self, value): return {"ok": False, "reason": "unsupported"}
        def set_focus(self, value): return {"ok": False, "reason": "unsupported"}
        def set_zoom(self, value): return {"ok": False, "reason": "unsupported"}
    d = Dummy()
    assert d.name == "dummy" and d.grab_frame() == b"JPEG"
    assert d.set_iso(1200) == {"ok": False, "reason": "unsupported"}
