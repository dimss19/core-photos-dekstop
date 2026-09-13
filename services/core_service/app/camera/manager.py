"""CameraManager: auto-detect order, single active adapter, PRD 6.2 status mapping."""
from app.camera.adapters import ICameraAdapter, CameraError

STATUS_READY = "Connected/Ready"
STATUS_DOWN = "Not Connected"
STATUS_ERROR = "Error"


class CameraManager:
    def __init__(self, adapters: list):
        self._adapters: list = list(adapters)
        self._active: ICameraAdapter | None = None
        self._detail: str = "no camera detected yet"

    @property
    def active(self):
        return self._active

    def detect(self) -> dict:
        for adapter in self._adapters:
            try:
                if adapter.detect():
                    adapter.connect()
                    self._active = adapter
                    self._detail = f"{adapter.name} connected"
                    return self.status()
            except CameraError as e:
                self._detail = str(e)
        self._active = None
        if "no camera detected yet" not in self._detail:
            self._detail = "no camera detected: check USB connection and retry"
        return self.status()

    def status(self) -> dict:
        if self._active is not None and self._active.is_connected():
            return {"status": STATUS_READY, "adapter": self._active.name, "detail": self._detail}
        if self._detail and "not detected" not in self._detail and "yet" not in self._detail and "disconnected" not in self._detail:
            return {"status": STATUS_ERROR, "adapter": None, "detail": self._detail}
        return {"status": STATUS_DOWN, "adapter": None, "detail": self._detail}

    def require_ready(self) -> ICameraAdapter:
        if self._active is None or not self._active.is_connected():
            raise CameraError("capture blocked: camera not ready")
        return self._active

    def connect_active(self) -> dict:
        return self.detect()

    def disconnect_all(self) -> dict:
        for adapter in self._adapters:
            adapter.disconnect()
        self._active = None
        self._detail = "disconnected by operator"
        return self.status()
