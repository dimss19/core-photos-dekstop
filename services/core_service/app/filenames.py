"""Filename parser/validator. Format: {HoleID}_{TrayNo}_{From:.2f}_{To:.2f}.jpg (PRD section 14)."""
import re

_PATTERN = re.compile(r"^([A-Za-z0-9_-]+)_([A-Za-z0-9_-]+)_(\d+\.\d{2})_(\d+\.\d{2})\.(jpg|JPG)$")


def parse_filename(name: str) -> dict:
    m = _PATTERN.match(name.strip())
    if not m:
        raise ValueError(f"invalid filename: {name!r}")
    hole_id, tray_no, frm, to, ext = m.groups()
    return {
        "hole_id": hole_id,
        "tray_no": int(tray_no) if tray_no.isdigit() else tray_no,
        "interval_from": float(frm),
        "interval_to": float(to),
        "ext": ext.lower(),
    }


def validate_filename(name: str) -> dict:
    try:
        p = parse_filename(name)
    except ValueError as e:
        return {"valid": False, "captureEnabled": False, "warning": str(e)}
    if p["interval_to"] < p["interval_from"]:
        return {"valid": False, "captureEnabled": False, "warning": "To < From"}
    return {"valid": True, "captureEnabled": True, "warning": "", "parsed": p}
