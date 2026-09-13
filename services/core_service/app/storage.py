"""Local storage helpers (PRD sections 15, 17). No overwrite; temp-file rename; MD5 verify."""
import hashlib
import json
import os


def md5_file(path: str) -> str:
    h = hashlib.md5()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


def resolve_tray_dir(base: str, session: str, hole: str, tray_label: str) -> str:
    """Return new tray dir path, creating it. Appends _v2/_v3 if HoleID/Tray already exists."""
    target = os.path.join(base, session, hole, tray_label)
    if not os.path.exists(target):
        os.makedirs(target)
        return target
    i = 2
    while True:
        cand = f"{target}_v{i}"
        if not os.path.exists(cand):
            os.makedirs(cand)
            return cand
        i += 1


def atomic_write_json(path: str, data: dict) -> None:
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)
    os.replace(tmp, path)


def build_sidecar(hole_id: str, tray_id: str, frm: float, to: float, filename: str,
                  md5: str, session: dict, extra: dict | None = None) -> dict:
    sidecar = {
        "hole_id": hole_id, "tray_id": tray_id,
        "interval_from": frm, "interval_to": to,
        "filename": filename, "md5": md5,
        "date": session.get("date"), "operator": session.get("operator"), "site": session.get("site"),
    }
    if extra:
        sidecar.update(extra)
    return sidecar
