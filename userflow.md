# User Flow — Aplikasi Core Photo (sesuai perilaku kode saat ini)

Dokumen ini menjelaskan alur pakai dari apa yang benar-benar dilakukan
aplikasi sekarang (Flutter `apps/flutter_app` + service `services/core_service`),
bukan dari target PRD. Semua endpoint di bawah adalah localhost
(`http://127.0.0.1:42839`).

---

## 1. Instalasi & menjalankan

1. Build manual (belum ada `Setup.exe` jadi):
   - Service: `python -m PyInstaller ... services/core_service/run.py`
     → `dist\core_service.exe` (sudah terbukti jalan, jawab `/healthz`).
   - UI: `flutter build windows --release` → `core_photo.exe`.
   - Script installer ada (`installer/corephoto.iss`) tapi belum dikompilasi
     (butuh Inno Setup `iscc`).
2. Jalankan `core_service.exe` dulu (atau `uvicorn app.main:app` saat develop),
   lalu jalankan `CorePhoto.exe`. **Aplikasi tidak auto-start service**
   (`SidecarLauncher` ada tapi belum dipakai `main.dart`).
3. DB SQLite dibuat otomatis di `%LOCALAPPDATA%\CorePhoto\data.db`
   (bisa dioverride via env `COREPHOTO_DB`). Log di `corephoto.log` folder sama.

## 2. Dashboard (tab Home)

- Menampilkan status kamera dari `GET /camera/status`
  (`Connected/Ready` | `Not Connected` | `Error`, atau `Unknown` bila service mati).
- Menampilkan session aktif (`Operator @ Site`, atau `-` bila belum ada).
- Daftar menu tap: Session, Capture, Photo Browser, Validation, Transfer, Settings.
- Tidak ada tombol Connect/Disconnect kamera di UI mana pun.

## 3. Session (tab Session)

- Form Date (default `2026-09-13`), Operator, Site + tombol **Create**.
- Operator kosong → error merah `Operator wajib diisi`, tidak ada request terkirim.
- Create → `POST /sessions` → session langsung jadi aktif + masuk daftar.
- Tiap baris daftar ada tombol **Activate** → session itu jadi aktif
  (dipakai layar Capture sebagai konteks).
- Data tersimpan di SQLite, survive restart service. Lanjutkan session lama
  dengan Activate ulang setelah restart (active-nya sendiri tidak persist).

## 4. Capture (tab Capture)

- Form 8 field: Hole ID, Tray ID, From, To, Rows, Length, Width, Comments.
- Warning merah live saat mengetik: ID kosong, interval bukan angka,
  atau `To < From`.
- Tombol **Validate Tray** → `POST /trays` (ditolak 422 bila interval invalid,
  404 bila session tak dikenal). Berhasil → tray tersimpan (`t1`, `t2`, …).
- Panel Live View: satu frame terakhir dari `GET /camera/frame` + overlay Grid
  + tombol **Refresh** (tidak ada video/MJPEG stream di UI, tidak ada kontrol Zoom).
- Tombol **Take Picture**: disabled sampai form valid **dan** Validate Tray sukses.
  Ditekan → `POST /captures` (nama file `Hole_Tray_From_To.jpg`, box selalu
  `[0, 0]`, folder output selalu relatif `captures/`) → polling job →
  otomatis pindah ke tab Review.
- File RAW disimpan di subfolder tray berversi otomatis
  (`.../HoleID_Label/`, `_v2` bila sudah ada). Tray tak dikenal → job error.

## 5. Review (tab Review)

- Kosong → teks `Belum ada hasil capture`, kedua tombol disabled.
- Ada hasil → kotak hitam menampilkan **teks path file** (bukan gambar),
  plus ID tray.
- **Save** → `POST /process`: crop 300×200 dari posisi Box hasil framing →
  JPG final pakai nama kanonis (`Core01_1_000.00_2.60.jpg`, lolos validator),
  RAW digeser ke `*_raw.jpg` (isi tak berubah), plus `*_thumb.jpg` +
  sidecar `{nama}.json` 16 field.
- **Retake** → `POST /captures/{job}/retake` (tray_id yang sama dipakai ulang):
  file baru di folder versi baru (`_v2`, …) — file capture asal utuh,
  lalu kembali ke Capture.

## 6. Photo Browser (tab Browser)

- Load `GET /photos` saat dibuka; kolom **Search** filter lokal by nama file
  atau Hole ID; kosong → `No photos`.
- Tiap baris: thumbnail (`.../file?variant=thumb`, ikon bila gagal load),
  nama file, `Hole · From–To`.
- Tap baris → dialog preview JPG penuh + tombol Tutup.

## 7. Validation (tab Valid)

- Isi Tray ID (mis. `t1`) → **Validate** → `POST /trays/validate`.
- Tampil status hijau `VALID` atau merah `INVALID` + daftar `field: masalah`
  (interval, filename, kelengkapan data). Status tersimpan di tray.
- INVALID → tombol **Edit & Re-validate**: form 8 field terisi data tray,
  ubah → **Save Correction** (`PATCH /trays/{id}`, ditolak 422 bila interval
  invalid) → status direset → validasi ulang otomatis. Foto baru yang masuk
  juga mereset status (wajib re-validate).

## 8. Transfer (tab Transfer)

- Daftar session dengan checkbox + kolom folder tujuan + tombol
  **Check Connection** → `reachable` / `unreachable: alasan`.
- Pilih ≥1 session (kosong → `Pilih minimal 1 session`) → **Start Transfer**.
- Progress bar (persen per file, dari polling job) + status: `Success: [...]`
  atau `Error: ...`. Copy jalan di thread latar — UI/API tetap responsif
  untuk file besar; MD5 dihitung streaming (hemat memori).
- Yang disalin per foto: RAW + JPG + thumb + sidecar JSON, dicek MD5 per file;
  gagal → job error berisi daftar file. File lokal **tidak dihapus**.
- **Retry** aktif setelah ada job → menjalankan ulang transfer yang sama
  (job baru). Tujuan yang didukung: `{"type":"folder","path":...}`
  (termasuk share termount); tipe lain → unreachable.

## 9. Settings (tab Config)

- Menampilkan base URL + status token (*** bila diisi, read-only).
- Label statis: ISO +1200, Focus Manual, Zoom 1.0x (display saja,
  bukan kontrol — kontrol ISO/Focus/Zoom hanya via API `/camera/settings`).
- Tabel **Kemampuan kamera** live dari `/camera/capabilities`
  (Ya/Tidak per Live View/ISO/Focus/Zoom/Capture).

## 10. Batasan yang masih berlaku

- Kamera nyata (Canon/Nikon/Sony) belum didukung — yang jalan `FakeAdapter`;
  tambah adapter = implementasi `ICameraAdapter` + daftarkan ke `CameraManager`.
- Framing: tap Live View menandai sudut Box Core (marker kuning + label
  `Box: x%, y%`); posisi itu yang dipakai crop (bukan [0,0]).
  Box selalu dijepit ke dalam foto.
  selalu relatif `captures/` (bukan Documents).
- Tidak ada login/user — siapa pun yang membuka aplikasi memakai data yang sama.
- Transfer sinkron di request (aman untuk file kecil/fake; RAW besar butuh
  worker thread — kontrak job tak berubah).
