"""Canonical validation (PRD sections 8, 16). UI mirrors To<From lightly; this module is authoritative."""


def validate_interval(frm: float, to: float) -> dict:
    if to < frm:
        return {"valid": False, "captureEnabled": False, "warning": "To < From"}
    return {"valid": True, "captureEnabled": True, "warning": ""}


def validate_tray(tray: dict) -> dict:
    errors: dict = {}
    if not str(tray.get("hole_id", "")).strip():
        errors["hole_id"] = "Hole ID wajib diisi"
    if not str(tray.get("tray_id", "")).strip():
        errors["tray_id"] = "Tray ID wajib diisi"
    try:
        frm = float(tray.get("interval_from"))
        to = float(tray.get("interval_to"))
    except (TypeError, ValueError):
        errors["interval"] = "Interval From/To harus angka"
        return {"valid": False, "captureEnabled": False, "errors": errors}
    iv = validate_interval(frm, to)
    if not iv["valid"]:
        errors["interval"] = iv["warning"]
    valid = not errors
    return {"valid": valid, "captureEnabled": valid, "errors": errors}
