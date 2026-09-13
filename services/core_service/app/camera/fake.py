"""FakeAdapter: synthetic camera proving the ICameraAdapter contract without hardware."""
import hashlib
import io
from PIL import Image, ImageDraw
from app.camera.adapters import ICameraAdapter, Capabilities, CameraError


class FakeAdapter(ICameraAdapter):
    def __init__(self, available: bool = True):
        self._available = available
        self._connected = False
        self._live = False
        self._frames = 0

    @property
    def name(self) -> str:
        return "fake"

    def detect(self) -> bool:
        return self._available

    def connect(self) -> None:
        if not self._available:
            raise CameraError("camera not detected: check USB connection and retry")
        self._connected = True

    def disconnect(self) -> None:
        self._connected = False
        self._live = False

    def is_connected(self) -> bool:
        return self._connected

    def get_capabilities(self) -> Capabilities:
        return Capabilities(supports_liveview=True, supports_iso=True, supports_focus=True, supports_zoom=True, supports_capture=True)

    def start_liveview(self) -> None:
        if not self._connected:
            raise CameraError("cannot start live view: camera not connected")
        self._live = True

    def stop_liveview(self) -> None:
        self._live = False

    def liveview_running(self) -> bool:
        return self._live and self._connected

    def _render(self, w: int, h: int) -> bytes:
        self._frames += 1
        img = Image.new("RGB", (w, h), (30 + self._frames % 40, 60, 90))
        ImageDraw.Draw(img).text((20, 20), f"FAKE frame {self._frames}")
        buf = io.BytesIO()
        img.save(buf, "JPEG", quality=85)
        return buf.getvalue()

    def grab_frame(self) -> bytes:
        if not self.liveview_running():
            raise CameraError("live view not running: call start first")
        return self._render(640, 480)

    def capture(self, dest_path: str) -> dict:
        if not self._connected:
            raise CameraError("capture blocked: camera not ready")
        data = self._render(800, 600)
        with open(dest_path, "wb") as f:
            f.write(data)
        return {"path": dest_path, "md5": hashlib.md5(data).hexdigest(), "bytes": len(data)}

    def set_iso(self, value) -> dict:
        return {"ok": True}

    def set_focus(self, value) -> dict:
        return {"ok": True}

    def set_zoom(self, value) -> dict:
        return {"ok": True}
