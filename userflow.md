# User Flow — Aplikasi Core Photo

Dokumen ini menjelaskan alur penggunaan aplikasi dari sudut pandang operator,
mengikuti PRD `PRD_AI_Agent_Core_Photo_v1.0.md`. Semua capture/processing/review/
validation/local storage berjalan **offline**; network hanya untuk Transfer.

---

## 1. Instalasi

1. Unduh `CorePhoto-Setup-vX.Y.Z.exe` (satu file installer).
2. Double-click → Next → pilih folder (default `Program Files\Core Photo`).
3. Installer memasang `CorePhoto.exe` (Flutter UI) + `core_service.exe`
   (Python local service) + SDK kamera + VC++ Redist bila belum ada.
4. Shortcut Start Menu / Desktop dibuat. Data runtime (SQLite, log, token)
   otomatis di `%LOCALAPPDATA%\CorePhoto\`; foto default di `Documents\CorePhoto\`
   (bisa diubah di Settings). Tidak perlu install Python/Flutter terpisah.
5. Update = jalankan installer versi baru (timpa exe saja; DB dan foto tidak dihapus).

## 2. Buka Aplikasi & Dashboard

1. Buka aplikasi dari shortcut → Flutter otomatis start `core_service.exe`
   dan health-check `127.0.0.1` (status koneksi service ditampilkan).
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
2. Di aplikasi: **Connect Camera** (atau otomatis saat buka Capture).
   - Terdeteksi → status `Connected/Ready`.
   - Tidak terdeteksi → error jelas + tombol Detect Again.
3. Atur bila perlu (Settings / layar Capture): ISO (acuan +1200),
   Focus, Zoom — yang tidak didukung kamera tetap aman (unsupported, tanpa crash).
4. Jika kamera putus di tengah workflow: Capture diblokir sampai kamera kembali.

## 5. Input Data Tray (PRD §7–§8)

1. Buka **Capture** → isi Tray Data:
   Hole ID, Tray ID, Core Interval From/To, Tray Rows, Tray Length,
   Tray Width, Comments.
2. **Interval Validation** otomatis:
   - `To < From` → warning + tombol **Take Picture disabled**.
   - Perbaiki nilai → valid → Capture aktif kembali.

## 6. Live View & Framing (PRD §9)

1. Letakkan tray/core di photography station.
2. Buka **Live View** (stream MJPEG localhost; Start/Stop lifecycle).
3. Pastikan posisi tray; gunakan **Grid** dan **Zoom overlay** untuk framing.
4. Lanjut ke Capture.

## 7. Capture (PRD §10)

1. Tekan **Take Picture** (aktif hanya jika Tray valid + kamera ready).
2. Foto diterima dari kamera → dikaitkan ke Session + Tray aktif.
3. Otomatis masuk layar **Review**.

## 8. Review & Retake (PRD §11)

1. Lihat hasil foto + metadata Tray.
2. Cocok → **Save** → lanjut Processing.
3. Tidak cocok → **Retake** → kembali Capture (metadata Tray tetap,
   hasil Retake yang dipakai).

## 9. Processing Otomatis (PRD §12–§13)

Setelah Save, tanpa aksi operator:

1. **RAW** (file original) disimpan apa adanya.
2. **Tray Crop** 300×200 patokan sudut Box Core.
3. **JPG** + **Thumbnail** dihasilkan dari area crop.
4. Filename format existing: `Core01_1_000.00_2.60.jpg` + sidecar `.json`
   metadata (Hole, Tray, Interval, MD5, Timestamp, dst).

## 10. Validation (PRD §16)

1. Status **VALID / INVALID** (cek: interval, filename, kelengkapan data).
2. INVALID → tampilkan masalah → **Correction** → validasi ulang.
3. VALID → **Tray Complete**.
4. Layar **Validation** menampilkan status + detail error/warning + aksi perbaiki.

## 11. Tray Berikutnya / Selesai

1. **More Tray? Yes** → kembali ke Input Data Tray (langkah 5).
2. **No** → session selesai → ke Transfer.
3. Aturan folder: Drillhole ID sama → folder baru otomatis (`_v2`, `_v3`);
   file lama tidak pernah tertimpa. File lokal tetap ada setelah Transfer.

## 12. Photo Browser (PRD §18, kapan saja)

1. Buka **Photo Browser** (data lokal, offline).
2. Search/filter by Drillhole → daftar foto + Tray info + interval.
3. Pilih item → Thumbnail + preview foto.

## 13. Transfer ke Server (PRD §19, butuh network)

1. Buka **Transfer** (terpisah dari capture).
2. Pilih Session/data → **Check Server Connection**.
   - Tidak bisa diakses → error + **Retry** (data lokal aman).
3. **Start Transfer** → progress/status ditampilkan.
4. **Validate Transfer** → Success (file lokal tetap disimpan, tidak dihapus)
   atau Error → Retry.

## 14. Settings (PRD §20.8)

1. Folder foto, Server URL, API token (bila dipakai).
2. Camera settings yang tersedia (ISO/Focus/Zoom capability-based).
3. Tentang aplikasi / versi.

## 15. Error Handling Ringkas (PRD §22)

| Kondisi | Tampilan |
|---|---|
| Kamera tidak terdeteksi / putus | Status + pesan + Detect Again; Capture diblokir |
| Capture gagal / setting unsupported | Pesan jelas, tanpa crash |
| Interval invalid / filename invalid | Warning + Capture disabled |
| Disk penuh / permission / write gagal | Pesan + aksi (bebaskan disk / cek izin) |
| RAW rusak / crop/JPG/thumb gagal | Pesan + ulangi processing |
| Server unreachable / transfer gagal | Error + Retry; data lokal aman |

---

*Sumber: PRD v1.0 + spec `docs/superpowers/specs/2026-09-13-core-photo-tech-stack-design.md`.*
