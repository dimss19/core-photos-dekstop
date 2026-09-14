# Build & Installer — Core Photo (Windows 10/11 64-bit)

Satu-satunya bagian yang butuh tool eksternal (di luar repo) adalah
kompilasi installer. Semua langkah di bawah sudah di-smoke-test pada
2026-09-14 kecuali `iscc` (Inno Setup belum terinstall di mesin ini).

## 1. Python sidecar → `core_service.exe` (TERBUKTI)

```powershell
pip install pyinstaller
python -m PyInstaller --onefile --noconfirm --name core_service `
  --paths services/core_service --distpath dist --workpath build-installer `
  services/core_service/run.py
# hasil: dist\core_service.exe  (~13 MB, tanpa Python terinstall)
```

Smoke test lolos:

```powershell
$env:COREPHOTO_DB = "$env:TEMP\corephoto-smoke.db"
$env:COREPHOTO_PORT = "42899"
Start-Process .\dist\core_service.exe
curl.exe --noproxy "*" http://127.0.0.1:42899/healthz
# {"ok":true,"version":"0.1.0","camera":"unknown","db":"ok"}
```

Catatan:

- `run.py` import `app` statis (jangan string `"app.main:app"` — tak terbaca PyInstaller).
- `check_same_thread=False` wajib (uvicorn melayani dari worker thread).
- PowerShell 5.1 `Invoke-WebRequest` gagal via proxy sistem untuk localhost;
  gunakan `curl.exe --noproxy "*"` (bukan bug aplikasi).

## 2. Flutter → `core_photo.exe` (TERBUKTI)

```powershell
cd apps\flutter_app
flutter build windows --release
# hasil: build\windows\x64\runner\Release\core_photo.exe
```

## 3. Setup.exe (butuh Inno Setup 6)

1. Install Inno Setup 6 (`iscc` di PATH).
2. Dari root repo: `iscc installer\corephoto.iss`
3. Hasil: `installer\Output\CorePhoto-Setup-0.1.0.exe` — double-click,
   tanpa install Python/Flutter terpisah, runtime tanpa admin.

## 4. Struktur runtime di laptop operator

```text
Program Files\CorePhoto\      CorePhoto.exe + core_service.exe + data\
%LOCALAPPDATA%\CorePhoto\     data.db (SQLite WAL) + corephoto.log
Documents\CorePhoto\          foto default (bisa diubah di Settings)
```

Uninstall menyisakan DB/foto/log (anti kehilangan data).
