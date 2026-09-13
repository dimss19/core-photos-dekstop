"""Universal camera adapter contract. Vendor adapters (Canon/Nikon/Sony) implement this ABC (Plan 5)."""
from abc import ABC, abstractmethod
from dataclasses import dataclass


class CameraError(Exception):
    """Raised for detect/connect/capture/liveview failures with operator-actionable message."""


@dataclass
class Capabilities:
    supports_liveview: bool = False
    supports_iso: bool = False
    supports_focus: bool = False
    supports_zoom: bool = False
    supports_capture: bool = False


class ICameraAdapter(ABC):
    @property
    @abstractmethod
    def name(self) -> str: ...

    @abstractmethod
    def detect(self) -> bool: ...

    @abstractmethod
    def connect(self) -> None: ...

    @abstractmethod
    def disconnect(self) -> None: ...

    @abstractmethod
    def is_connected(self) -> bool: ...

    @abstractmethod
    def get_capabilities(self) -> Capabilities: ...

    @abstractmethod
    def start_liveview(self) -> None: ...

    @abstractmethod
    def stop_liveview(self) -> None: ...

    @abstractmethod
    def liveview_running(self) -> bool: ...

    @abstractmethod
    def grab_frame(self) -> bytes: ...

    @abstractmethod
    def capture(self, dest_path: str) -> dict: ...

    @abstractmethod
    def set_iso(self, value) -> dict: ...

    @abstractmethod
    def set_focus(self, value) -> dict: ...

    @abstractmethod
    def set_zoom(self, value) -> dict: ...
