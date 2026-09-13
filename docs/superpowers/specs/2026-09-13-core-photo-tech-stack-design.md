# Design Spec — Core Photo Desktop Tech Stack (Flutter + Python Sidecar)

**Date:** 2026-09-13
**Source PRD:** `PRD_AI_Agent_Core_Photo_v1.0.md`
**Status:** Approved per-section by user, pending final file review
**Scope:** Tech stack + arsitektur + kontrak + camera + storage + installer. Tanpa fitur di luar PRD.

## 0. Keputusan

Opsi A dipilih: **Flutter UI + Python local sidecar dalam 1 installer Windows.**

- `CorePhoto.exe` = Flutter + Dart, UI utama desktop.
- `core_service.exe` = Python frozen (PyInstaller onefile), local core service di workstation. Bukan cloud backend.
- Komunikasi hanya via localhost `127.0.0.1`, tidak diekspos ke network lain.
- Target: Windows 10/11 64-bit only, 1x `Setup.exe`, double-click langsung jalan, tanpa install Python/Flutter terpisah. Semua workflow Capture/Review/Processing/Validation/Local Storage offline. Network hanya untuk Transfer.

Opsi yang ditolak: B (Flutter only via FFI — ekosistem RAW/multi-vendor lemah), C (Python only PyQt — buang Flutter, UI lebih lambat dibangun).

## 1. Arsitektur Proses (Approved + penyesuaian)

- 2 proses dalam 1 installer: `CorePhoto.exe` + `core_service.exe`.
- Lifecycle (implementation detail, bukan business rule): Flutter start/stop sidecar saat dibuka/ditutup, `GET /healthz`, token file lokal (Bearer), single-instance mutex, auto-restart bila crash.
- Kepemilikan state tegas, tanpa duplikat:
  - Flutter = authoritative owner UI + application workflow state: `SESSION_CREATED → CAMERA_READY → TRAY_INPUT → READY_TO_CAPTURE → CAPTURING → REVIEWING → PROCESSING → VALIDATING → TRAY_COMPLETED → NEXT_TRAY / SESSION_DONE` (PRD §21). Validasi ringan `To < From` di UI untuk disable Capture.
  - Python = owner operation/job state + operasi berat: Camera Layer, Capture, RAW Processing, JPG/Thumbnail, filename parser/validator, Validation, Storage (SQLite + filesystem), Transfer, Logging. Python hanya mengembalikan status/result/error job, tidak menyimpan workflow state tandingan.
- Operasi berat async via job: `POST → {job_id}`, `GET /jobs/{job_id} → {status, progress, result, error}`. UI tidak boleh freeze (PRD §23).
- Port localhost configurable/reserved (contoh 42839), bukan business requirement.
- Larangan: tidak ada cloud backend / remote API / service eksternal untuk workflow utama.

## 2. Kontrak Flutter ↔ Python (Baseline approved)

Base: `http://127.0.0.1:{port}` + `Authorization: Bearer <local-token>`. Error envelope: `{code, message, hint}`.

- `GET /healthz` → `{ok, version, camera, db}`.
- `GET /jobs/{id}` → `{status: queued|running|done|error, progress, result, error}`.
- Session (PRD §5): `POST /sessions`, `GET /sessions`, `POST /sessions/{id}/activate`, `GET /sessions/active`. Field: date, operator, site.
- Camera (PRD §6): `GET /camera/status`, `POST /camera/connect`, `POST /camera/disconnect`, `POST /camera/liveview/start`, `POST /camera/liveview/stop`, `GET /camera/liveview.mjpg` (MJPEG, localhost only), `POST /camera/settings {iso, focus, zoom}`, `GET /camera/capabilities`.
- Tray + Capture (PRD §7/8/10/11): `POST /trays/validate-interval {from,to} → {valid, captureEnabled, warning}`, `POST /captures {session_id, tray} → job_id`, `GET /captures/{id}/preview`, `POST /captures/{id}/save → processing job_id`, `POST /captures/{id}/retake → job_id baru (metadata tray sama)`.
- Data (PRD §14/16/18): `POST /filenames/validate`, `POST /filenames/parse`, `GET /trays/{id}/validation`, `GET /photos?drillhole=&session_id=`, `GET /photos/{id}`, `GET /photos/{id}/file?variant=raw|jpg|thumb`.
- Transfer (PRD §19): `POST /transfer/check`, `POST /transfer {session_ids} → job_id`, `POST /transfer/{id}/retry`, `GET /transfer/{id}/validation`.
- Settings (PRD §20.8): `GET /settings`, `PUT /settings`.

Aturan: Capture/Processing/Transfer wajib async via job. Sync hanya untuk validasi cepat dan query. Live View lifecycle via start/stop. Camera settings capability-based, unsupported tanpa crash. Tidak ada endpoint/logic di luar PRD.

## 3. Camera Layer (Approved + catatan)

- Abstraksi wajib: `ICameraAdapter` dengan `detect/connect/disconnect/status/start_liveview/stop_liveview/get_frame/capture/set_iso/set_focus/set_zoom/get_capabilities`. Flutter dilarang akses SDK langsung.
- `CameraManager` (Python): auto-detect Canon → Nikon → Sony → Generic-PTP, pegang 1 adapter aktif, map ke `Connected/Ready | Not Connected | Error` (PRD §6.2). Putus saat workflow → blokir capture + error jelas + detect-again.
- Adapter: Canon EDSDK DLL, Nikon SDK, Sony Remote SDK (DLL dibundel), fallback Generic PTP/WPD hanya sesuai capability — jangan asumsikan semua kamera bisa capture via fallback.
- Live View: thread khusus Python ambil frame SDK → MJPEG localhost. Grid/Zoom/framing overlay di Flutter.
- ISO acuan +1200 adalah kalibrasi, bukan business rule baru — mapping mengikuti representasi/API tiap vendor. Focus/Zoom manual bila unsupported.
- Error PRD §22: tidak terdeteksi, disconnected, capture gagal, setting unsupported — semua dengan pesan + tindakan operator.

## 4. DB / Storage (Approved + catatan)

- SQLite 1 file: `%LOCALAPPDATA%\CorePhoto\data.db`, WAL mode. Read/write hanya Python; Flutter via API.
- Skema minimal (tidak tambah tabel di luar ini):
  - `sessions(id, date, operator, site, created_at)`
  - `trays(id, session_id, hole_id, tray_id, interval_from, interval_to, rows, length, width, comments, crop, validation)`
  - `photos(id, tray_id, filename, raw_path, jpg_path, thumb_path, md5, timestamp)`
  - `transfers(id, session_id, selection, status, progress, validated_at, error)`
- Filesystem (implementation decision, bukan business rule PRD): `base\{Session_Date}\{HoleID}\{Tray_Interval}\` berisi RAW original (jangan diubah), JPG + Thumbnail dari Tray Crop 300×200 patokan sudut Box Core (PRD §13), + `.json` sidecar metadata (Hole, Tray, Interval, Path, Comments, Date, Name, Site, MD5, Timestamp, Rows, Length, Width, Crop) untuk Browser + Transfer.
- Filename `Core01_1_000.00_2.60.jpg` dipertahankan (PRD §14). Parser/validator di Python terpisah dari UI.
- Anti-overwrite (PRD §17.1): HoleID sama → folder baru `_v2/_v3` otomatis. Tulis via temp-file → rename + verifikasi MD5. File lokal tetap ada setelah Transfer.
- Logging file untuk camera, capture, processing, validation, file op, transfer (PRD §23).

## 5. Installer Single-Setup Windows (Approved)

- Tool: Inno Setup → `CorePhoto-Setup-vX.Y.Z.exe`, offline.
- Isi: `CorePhoto.exe` (Flutter release windows), `core_service.exe` (Python frozen + OpenCV/Pillow/rawpy/numpy vendored), SDK DLL, config localhost, VC++ Redist 2015-2022 check/bundel.
- Lokasi: Program Files (read-only) + data runtime `%LOCALAPPDATA%\CorePhoto\` (db, token, logs) + folder foto default `Documents\CorePhoto` (dapat diubah di Settings). Runtime tanpa admin. Update timpa exe saja, DB/foto tidak dihapus. Uninstall sisakan data + konfirmasi.
- Verifikasi: VM bersih Win10/11 tanpa Python tanpa internet → capture → save → JPG/Thumb → validation → browser jalan; cabut kamera tidak crash; `To<From` → warning + capture disabled.

## 6. Non-Goals / Batasan

- Tanpa mobile/tablet, tanpa cloud backend, tanpa fitur kamera/storage/transfer di luar PRD §6/§17/§19.
- Tanpa business rule crop/validation/filename baru di luar PRD §13/§14/§16.
- Business logic harus dapat diuji independen dari UI (PRD §27). P0 sebelum P1 sebelum P2.

## 7. TODO: NEEDS CONFIRMATION

- Protokol tujuan Transfer Server (SMB share / HTTP upload / SFTP?) belum ditentukan di PRD §19 — mempengaruhi modul Transfer. Default desain: `POST /transfer` menerima `destination {type, path/url}` generik agar tidak mengunci protokol sebelum konfirmasi.
