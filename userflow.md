# User Flow — Aplikasi Core Photo

Dokumen ini menjelaskan alur penggunaan aplikasi dari sudut pandang operator,
mengikuti PRD `PRD_AI_Agent_Core_Photo_v1.0.md`. Semua capture/processing/review/
validation/local storage berjalan **offline**; network hanya untuk Transfer.

---

## 1. Instalasi

1. Unduh `CorePhoto-Setup-vX.Y.Z.exe` (satu file installer).
2. Double-click → Next → pilih folder (default `Program Files\Core Photo`).
3. Installer memasang `CorePhoto.exe` (Flutter UI) + `core_service.exe`
   (Python local service) + VC++ Redist bila belum ada. Script installer
   di `installer/corephoto.iss` (kompilasi via `iscc`, lihat `installer/BUILD.md`).
   Driver/SDK kamera vendor (Canon/Nikon/Sony) fase hardware; saat ini
   service memakai adapter kamera generik.
4. Shortcut Start Menu / Desktop dibuat. Data runtime (SQLite, log, token)
   otomatis di `%LOCALAPPDATA%\CorePhoto\`; foto default di `Documents\CorePhoto\`
   (bisa diubah di Settings). Tidak perlu install Python/Flutter terpisah.
5. Update = jalankan installer versi baru (timpa exe saja; DB dan foto tidak dihapus).

## 2. Buka Aplikasi & Dashboard

1. Buka aplikasi dari shortcut. Jika `core_service.exe` belum jalan
   (mis. development), jalankan manual / via SidecarLauncher sebelum membuka
   layar yang butuh API — Dashboard menampilkan status koneksi service.
   (Auto-start sidecar dari Flutter menyusul paket installer final.)
2. Dashboard menampilkan:
   - Session aktif (atau "-");
   - Status kamera (`Connected/Ready` | `Not Connected` | `Error`);
   - Menu: Session, Capture, Photo Browser, Validation, Transfer, Config.

## 3. Session (PRD §5)

1. Buka menu **Session**.
2. **Create**: isi Date, Operator, Site → session baru otomatis jadi aktif.
3. **Open/Continue**: pilih session dari daftar → jadikan aktif (Activate).
4. Session aktif = konteks untuk semua capture berikutnya.

## 4. Siapkan Kamera (PRD §6)

1. Hubungkan kamera DSLR/Mirrorless (Canon/Nikon/Sony) via USB ke workstation.
2. Status kamera tampil di Dashboard (`Connected/Ready` | `Not Connected` | `Error`).
   Koneksi dilakukan via endpoint `POST /camera/connect` (otomatis saat service
   start dengan adapter yang tersedia); kamera tak terdeteksi → status Error
   dengan detail, dan Capture diblokir sampai kamera kembali.
3. Lihat capability nyata di **Settings** (Live View/ISO/Focus/Zoom/Capture:
   Ya/Tidak). ISO acuan +1200; yang unsupported tetap aman tanpa crash.
4. Jika kamera putus di tengah workflow: Capture diblokir sampai kamera kembali.

## 5. Input Data Tray (PRD §7–§8)

1. Buka **Capture** → isi Tray Data:
   Hole ID, Tray ID, Core Interval From/To, Tray Rows, Tray Length,
   Tray Width, Comments.
2. **Interval Validation** otomatis saat mengetik:
   - `To < From` → warning + tombol **Take Picture disabled**.
   - Perbaiki nilai → warning hilang.
3. Tekan **Validate Tray** → tray tersimpan di server. Baru setelah itu
   **Take Picture** aktif (syarat: form valid + tray tersimpan + kamera ready).

## 6. Live View & Framing (PRD §9)

1. Letakkan tray/core di photography station.
2. Panel **Live View** menampilkan frame terakhir dari kamera
   (`GET /camera/frame`) + overlay **Grid**; tekan **Refresh** untuk frame baru.
   (Stream MJPEG kontinu tersedia di endpoint `/camera/liveview.mjpg` untuk
   fase berikutnya.)
3. Pastikan posisi tray, lalu lanjut ke Capture.

## 7. Capture (PRD §10)

1. Tekan **Take Picture** (aktif hanya jika form valid + tray tersimpan
   via Validate Tray + kamera ready).
2. Foto diterima dari kamera → disimpan sebagai RAW di folder tray versi
   (`.../HoleID_LabelTray/`; otomatis `_v2`, `_v3` bila sudah ada) → dikaitkan
   ke Session + Tray aktif.
3. Otomatis masuk layar **Review**.

## 8. Review & Retake (PRD §11)

1. Lihat hasil foto + metadata Tray.
2. Cocok → **Save** → lanjut Processing.
3. Tidak cocok → **Retake** → kembali Capture (metadata Tray tetap,
   hasil Retake yang dipakai).

## 9. Processing Otomatis (PRD §12–§13)

Setelah Save, tanpa aksi operator:

1. **RAW** (file original, mis. `Core01_1_000.00_2.60.jpg`) disimpan apa adanya.
2. **Tray Crop** 300×200 patokan sudut Box Core.
3. **JPG** (`*_display.jpg`) + **Thumbnail** (`*_thumb.jpg`) dihasilkan dari area crop.
4. Format filename dipertahankan (`Core01_1_000.00_2.60.jpg`; From dipad
   `000.00` persis contoh PRD) + sidecar `{nama}.json` metadata lengkap
   16 field PRD (Hole, Tray, Interval, Path, Comments, Date, Operator, Site,
   MD5, Timestamp, Rows, Length, Width, Crop).

## 10. Validation (PRD §16)

1. Status **VALID / INVALID** (cek: interval, filename, kelengkapan data).
2. INVALID → tampilkan masalah → **Correction** → validasi ulang.
3. VALID → **Tray Complete**.
4. Layar **Validation** menampilkan status + detail error/warning + aksi perbaiki.

## 11. Tray Berikutnya / Selesai

1. **More Tray? Yes** → kembali ke Input Data Tray (langkah 5).
2. **No** → session selesai → ke Transfer.
3. Aturan folder: setiap capture tersimpan di folder tray versi otomatis
   (`_v2`, `_v3` bila label sama sudah ada) — file lama tidak pernah tertimpa.
   Retake menimpa file capture-nya sendiri (by design: hasil Retake yang dipakai).
   File lokal tetap ada setelah Transfer.

## 12. Photo Browser (PRD §18, kapan saja)

1. Buka **Photo Browser** (data lokal SQLite, offline).
2. Search/filter by Drillhole → daftar foto + Tray info + interval + Thumbnail.
3. Tap item → dialog preview foto ukuran penuh.

## 13. Transfer ke Server (PRD §19, butuh network)

1. Buka **Transfer** (terpisah dari capture).
2. Isi folder tujuan (mendukung path lokal / share termount) → **Check Connection**.
   - Tidak bisa ditulis → unreachable + detail (data lokal aman).
3. Centang Session → **Start Transfer** → progress/status ditampilkan.
4. Validasi MD5 per file → **Success** (file lokal tetap disimpan, tidak dihapus)
   atau **Error** + daftar file gagal → **Retry**.

## 14. Settings (PRD §20.8)

1. Server URL + API token (ditampilkan; diedit di kode/build berikutnya).
2. ISO acuan +1200, Focus/Manual, Zoom — plus tabel **Kemampuan kamera**
   nyata dari adapter (Ya/Tidak per Live View/ISO/Focus/Zoom/Capture).
3. Tentang aplikasi / versi.

## 15. Error Handling Ringkas (PRD §22)

| Kondisi | Tampilan |
|---|---|
| Kamera tidak terdeteksi / putus | Status Error + detail; Capture diblokir; hubungkan ulang + Activate session bila perlu |
| Capture gagal / setting unsupported | Pesan jelas, tanpa crash |
| Interval invalid / filename invalid | Warning + Capture disabled |
| Disk penuh / permission / write gagal | Pesan + aksi (bebaskan disk / cek izin) |
| RAW rusak / crop/JPG/thumb gagal | Pesan + ulangi processing |
| Server unreachable / transfer gagal | Error + Retry; data lokal aman |

---

*Sumber: PRD v1.0 + spec `docs/superpowers/specs/2026-09-13-core-photo-tech-stack-design.md`.*
