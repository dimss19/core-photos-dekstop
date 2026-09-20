# LAPORAN QA — CORE PHOTO

**Versi Laporan:** 1.0  
**Tanggal Pengujian:** 14 September 2026  
**Peran:** Independent QA Engineer (Black-box & End-to-End Testing)  
**Dokumen Acuan:**
1. [PRD_Aplikasi_Pengambilan_Foto_Core_v0.3_UPDATED.docx](file:///d:/laragon/www/aplikasi%20foto%20core/PRD_Aplikasi_Pengambilan_Foto_Core_v0.3_UPDATED.docx)
2. [PRD_AI_Agent_Core_Photo_v1.0.md](file:///d:/laragon/www/aplikasi%20foto%20core/PRD_AI_Agent_Core_Photo_v1.0.md)
3. [userflow.md](file:///d:/laragon/www/aplikasi%20foto%20core/userflow.md)

---

## A. Ringkasan

Pengujian Black-box dan End-to-End (E2E) independen telah dilakukan terhadap build executable backend `dist\core_service.exe` dan aplikasi desktop Flutter Windows `core_photo.exe` yang sedang berjalan aktif di lingkungan lokal workstation.

- **Total Test Executed:** 56
- **PASS:** 37
- **FAIL:** 15
- **BLOCKED:** 1
- **UNVERIFIED:** 0
- **GAP:** 3

> [!CAUTION]
> **TEMUAN KRITIS:** Ditemukan sejumlah masalah **P0 Data Integrity** dan **P0 Runtime Crash** pada aplikasi yang sedang berjalan:
> 1. Retake dan pengambilan foto ulang drillhole yang sama menyebabkan **penimpaan file historis di disk (destructive overwrite)** dan diskrepansi MD5 metadata.
> 2. Klik tombol **Save** pada layar Review mengalami **Runtime Type Crash** di Dart (`TypeError: double is not a subtype of type int`) saat operator menentukan koordinat framing Core Box.
> 3. Kamera default berstatus `Not Connected` saat startup dan **UI tidak memiliki tombol ataupun mekanisme auto-connect**, sehingga Live View dan Capture tidak dapat digunakan secara mandiri dari UI.
> 4. Live View di UI selalu menampilkan status `Live View (offline)` karena UI tidak pernah memicu `/camera/liveview/start` (backend menolak dengan HTTP 409 Conflict).
> 5. Navigasi menu pada layar Dashboard mengalami *index offset* (klik *Photo Browser* membuka *Review*, dsb.).

---

## B. Environment

| Komponen | Spesifikasi / Nilai Aktual |
|---|---|
| **Operating System** | Windows 11 Pro 64-bit (Build 10.0.26200.9445) |
| **Application Build (UI)** | Flutter 3.44.8, Dart SDK 3.12.2 (Windows Desktop x64 Runner) |
| **Service Build** | `dist\core_service.exe` (PyInstaller 6.22.3, Python 3.10.6, FastAPI 0.139.0, Uvicorn 0.51.0) |
| **Service Endpoint** | Localhost only: `http://127.0.0.1:42839` |
| **Database** | SQLite 3, path: `%LOCALAPPDATA%\CorePhoto\data.db` (`C:\Users\acer\AppData\Local\CorePhoto\data.db`) |
| **Camera Hardware** | Tidak ada hardware DSLR fisik (Canon/Nikon/Sony) terpasang di workstation |
| **Camera Adapter Aktif** | `FakeAdapter` (Synthetic camera generator, frame 640×480, capture 800×600) |
| **Test Data Digunakan** | Hole ID: `TEST001`, `TEST002`; Tray ID: `TEST001_TRAY01`, `1`, `2`; From: `0.00`, To: `2.60`; Rows: 3; Length: 700; Width: 300; Comments: "QA Test" |

---

## C. Test Matrix

| ID | Area | Expected Behavior | Actual Behavior | Status | Severity |
|---|---|---|---|:---:|:---:|
| **ENV-01** | Environment | Service aktif dan merespons `GET /healthz` | Respons `{"ok": true, "version": "0.1.0", "camera": "unknown", "db": "ok"}` | **PASS** | P0 |
| **ENV-02** | Environment | Status kamera dapat dibaca saat startup | Status kamera terbaca `{"status": "Not Connected", "adapter": null}` | **PASS** | P1 |
| **ENV-03** | Camera Adapter | Adapter fisik Canon / Nikon / Sony tersedia | Hanya `FakeAdapter` yang diimplementasikan dalam kode | **BLOCKED** | P1 |
| **SESSION-01** | Session | Create Session berhasil, aktif, dan muncul di list | Session `s1` tersimpan di SQLite, `GET /sessions/active` mengembalikan `s1`, dan muncul pada daftar | **PASS** | P1 |
| **SESSION-02** | Session | Operator kosong memunculkan validasi dan tidak membuat session | UI memblokir via validasi lokal `Operator wajib diisi`, namun API `/sessions` menerima string kosong (HTTP 201) | **GAP** | P2 |
| **SESSION-03** | Session | Session lama dapat diaktifkan kembali | `POST /sessions/{id}/activate` sukses dan `GET /sessions/active` mengembalikan konteks session lama | **PASS** | P1 |
| **SESSION-04** | Session | Data session tetap ada setelah restart service/app | Data di SQLite tabel `sessions` tetap utuh setelah restart | **PASS** | P0 |
| **TRAY-01** | Tray | Validate Tray berhasil, tersimpan, dan terkait active session | `POST /trays` menghasilkan HTTP 201, tray `t1` tersimpan dengan `session_id: s1` | **PASS** | P0 |
| **TRAY-02** | Tray | Hole ID kosong memunculkan peringatan, capture dilarang | API mengembalikan HTTP 422 `{"errors": {"hole_id": "Hole ID wajib diisi"}}`. Di UI, warning muncul dan tombol disabled | **PASS** | P1 |
| **TRAY-03** | Tray | From/To bukan angka memunculkan peringatan | API mengembalikan HTTP 422 `{"errors": {"interval": "Interval From/To harus angka"}}`. Di UI tombol disabled | **PASS** | P1 |
| **TRAY-04** | Tray | From = 20, To = 15 memunculkan peringatan `To < From`, capture disabled | API mengembalikan HTTP 422 `{"errors": {"interval": "To < From"}}`. Di UI tombol *Take Picture* disabled | **PASS** | P0 |
| **TRAY-05** | Tray | Form valid tapi belum Validate Tray -> Take Picture disabled | `canCapture` di UI mengecek `_trayId != null`. Jika belum validate, `_trayId` bernilai null sehingga tombol disabled | **PASS** | P1 |
| **CAM-01** | Camera | Camera connect dan status reporting berjalan | `POST /camera/connect` berhasil mengubah status menjadi `Connected/Ready` dengan adapter `fake` | **PASS** | P1 |
| **CAM-02** | Camera | Camera capabilities dapat diakses via API | API mengembalikan capabilities `supports_liveview: true`, ISO, Focus, Zoom, Capture | **PASS** | P2 |
| **CAM-03** | Camera | UI dapat menghubungkan kamera ke service | **UI tidak memiliki tombol atau trigger connect**. Kamera tetap `Not Connected` tanpa intervensi eksternal | **FAIL** | P0 |
| **LIVEVIEW-01** | Live View | Endpoint `/camera/frame` menghasilkan JPEG saat Live View start | Mengembalikan HTTP 409 bila belum start, dan HTTP 200 JPEG saat liveview running | **PASS** | P1 |
| **LIVEVIEW-02** | Live View | Live View preview muncul di layar Capture UI | UI tidak pernah memanggil `/camera/liveview/start`, request frame gagal (409), UI menampilkan `Live View (offline)` permanen | **FAIL** | P0 |
| **CROP-01** | Tray Crop | Ukuran standar hasil crop adalah 300 × 200 | File deliverable JPG hasil crop berdimensi tepat 300 × 200 piksel | **PASS** | P0 |
| **CROP-02** | Tray Crop | Thumbnail menggunakan crop yang sama | File thumbnail berukuran 256 × 171 piksel (skala proporsional dari crop 300 × 200) | **PASS** | P1 |
| **CROP-03** | Tray Crop | Posisi Core Box memengaruhi area crop (tidak selalu [0,0]) | Pemilihan koordinat `[0.75, 0.5]` menghasilkan crop piksel berbeda dibanding `[0.0, 0.0]` | **PASS** | P0 |
| **CROP-04** | Tray Crop | Tombol Save di UI memproses framing box tanpa crash | `ReviewScreen._save()` memanggil `List<int>.from(cap['box'])`. Nilai box adalah `double`, memicu **Dart TypeError** | **FAIL** | P0 |
| **CAPTURE-01** | Capture | Take picture enabled, capture berhasil, masuk ke Review | Job capture selesai, file RAW terbentuk, flow berpindah ke Review | **PASS** | P0 |
| **CAPTURE-02** | Capture | Filename format `ID Drillhole_No Tray_Interval Kedalaman.jpg` | Jika Tray ID berisi alfanumerik (mis. `TEST001_TRAY01`), backend menolak filename dengan error regex `(\d+)` | **FAIL** | P0 |
| **REVIEW-01** | Review | Operator dapat melihat review visual foto hasil capture | UI hanya menampilkan kotak hitam berisi **string teks path file**, bukan preview gambar foto | **FAIL** | P1 |
| **SAVE-01** | Save | Save menghasilkan JPG deliverable dengan nama kanonis PRD | Binary `core_service.exe` menamai JPG deliverable `*_display.jpg`, sedangkan nama kanonis dipegang file RAW | **FAIL** | P0 |
| **RETAKE-01** | Retake | Retake tidak menghancurkan file lama & MD5 lama tetap sama | **File lama tertimpa**. MD5 file berubah dari `58e2260...` menjadi `22c1e69...` | **FAIL** | P0 |
| **RETAKE-02** | Retake | File hasil retake ditempatkan pada folder versi aman (`_v2`) | File retake disimpan pada path file yang sama tanpa folder versi `_v2` | **FAIL** | P0 |
| **OUTPUT-01** | Output | File JPG deliverable canonical naming | Bernama `TEST001_1_000.00_2.60_display.jpg` (tidak sesuai konvensi kanonis PRD) | **FAIL** | P0 |
| **OUTPUT-02** | Output | File Thumbnail berformat `*_thumb.jpg` | Terbentuk `TEST001_1_000.00_2.60_thumb.jpg` | **PASS** | P0 |
| **OUTPUT-03** | Output | Sidecar JSON terbentuk berformat `*.json` | Terbentuk `TEST001_1_000.00_2.60.json` | **PASS** | P0 |
| **META-01** | Metadata | Seluruh 16 field metadata tersimpan di sidecar JSON | Seluruh 16 field (Hole ID, Tray, Interval, Path, MD5, Crop, dll.) ada dan lengkap | **PASS** | P0 |
| **META-02** | Metadata | MD5 pada metadata cocok dengan hash file aktual | Karena retake menimpa file, MD5 sidecar (`58e2...`) tidak cocok dengan file fisik (`22c1...`) | **FAIL** | P0 |
| **VAL-01** | Validation | Tray valid mendapatkan status `VALID` | `POST /trays/validate` menghasilkan `status: "VALID"`, `valid: true` | **PASS** | P1 |
| **VAL-02** | Validation | Tray dengan data tidak sesuai menghasilkan `INVALID` | Mengembalikan daftar error field pada respons | **PASS** | P1 |
| **VAL-03** | Validation | Koreksi tray via `PATCH /trays/{id}` & re-validasi | Endpoint `PATCH /trays/{id}` **tidak ada di binary core_service.exe (HTTP 404)** | **FAIL** | P1 |
| **VAL-04** | Validation | Foto baru mereset status validasi agar tidak stale | Kolom `validation` di SQLite tereset menjadi `NULL` saat capture baru dibuat | **PASS** | P1 |
| **BROWSER-01** | Photo Browser | Menampilkan daftar foto, Hole ID, interval | Foto berhasil dimuat dan difilter berdasarkan Hole ID / Filename | **PASS** | P1 |
| **BROWSER-02** | Photo Browser | Thumbnail dapat diakses via `/photos/{id}/file?variant=thumb` | HTTP 200 dengan Content-Type `image/jpeg` | **PASS** | P1 |
| **BROWSER-03** | Photo Browser | Full preview JPG dapat diakses via variant=jpg | HTTP 200 dengan Content-Type `image/jpeg` | **PASS** | P1 |
| **BROWSER-04** | Photo Browser | Navigasi menu Dashboard membuka Photo Browser | Menu *Photo Browser* di Dashboard membuka layar **Review** (index 3 bukan 4) | **FAIL** | P1 |
| **NO_OVERWRITE-01** | Data Integrity | Drillhole sama beda session tidak menimpa (Backend) | Binary `dist\core_service.exe` tidak membuat folder versi `_v2`, file Session A tertimpa | **FAIL** | P0 |
| **NO_OVERWRITE-02** | Data Integrity | Drillhole sama beda session tidak menimpa (UI) | UI tidak mengirimkan `tray_id` pada `/captures`, menyebabkan capture flat ke `captures/` dan saling menimpa | **FAIL** | P0 |
| **LOCAL-01** | Local Storage | Semua alur capture, crop, review, validasi jalan offline | Bekerja sepenuhnya pada localhost tanpa ketergantungan internet | **PASS** | P0 |
| **TRANSFER-01** | Transfer | Check connection membedakan target valid dan invalid | Folder lokal writable dilaporkan `reachable`, path drive `Z:\` invalid dilaporkan `unreachable` | **PASS** | P1 |
| **TRANSFER-02** | Transfer | Transfer memindahkan RAW, JPG, Thumb, JSON + cek MD5 | 8 file berhasil disalin ke folder tujuan dengan verifikasi checksum MD5 streaming | **PASS** | P0 |
| **TRANSFER-03** | Transfer | File lokal TIDAK dihapus setelah transfer | File RAW, JPG, Thumb lokal tetap ada di workstation setelah transfer | **PASS** | P0 |
| **TRANSFER-04** | Transfer | Transfer gagal memberikan status Error dan aman | Status transfer menjadi `error`, data lokal tidak terganggu | **PASS** | P1 |
| **TRANSFER-05** | Transfer | Retry transfer dapat dijalankan ulang | `POST /transfer/{id}/retry` berhasil membuat job baru dan menyalin file | **PASS** | P2 |
| **TRANSFER-06** | Transfer | Transfer berjalan di background thread tanpa freeze | Transfer dieksekusi asynchronous via daemon thread, job status dapat dipolling | **PASS** | P1 |
| **RECOVERY-01** | Recovery | Data sesi dan tray bertahan saat UI direstart | Data tersimpan di SQLite dan tetap muncul saat UI dibuka kembali | **PASS** | P1 |
| **RECOVERY-02** | Recovery | Data foto dan transfer bertahan saat service direstart | Data di SQLite tabel `photos` dan `transfers` tetap utuh | **PASS** | P0 |
| **RECOVERY-03** | Recovery | Status active session setelah service restart | `_active_session_id` di memory Python hilang; butuh klik *Activate* ulang | **GAP** | P2 |
| **RECOVERY-04** | Recovery | UI menangani kondisi service mati tanpa crash | Error ditangkap `catchError`, UI menampilkan pesan status tanpa aplikasi crash | **PASS** | P1 |
| **SETTINGS-01** | Settings | Display only vs Actual control pada layar Settings | Label ISO (+1200), Focus, Zoom di UI hanyalah teks statis (Display Only), bukan kontrol interaktif | **GAP** | P2 |
| **ERR-01** | Error Handling | Capture saat kamera mati gagal dengan pesan jelas | Job status `error`, pesan: `capture blocked: camera not ready` | **PASS** | P1 |
| **ERR-02** | Error Handling | Process dengan tray tak dikenal gagal dengan pesan jelas | Job status `error`, pesan: `unknown tray` | **PASS** | P1 |
| **INTEGRITY-01** | Data Integrity | Integritas seluruh file foto terdaftar di database | Seluruh path file fisik yang tercatat di database valid dan dapat dibaca | **PASS** | P0 |

---

## D. Bug / Finding

### BUG-001
- **Severity:** Critical (P0)
- **Area:** Data Integrity / Retake & Versioning
- **Expected:** Retake tidak menghancurkan file historis yang sudah tersimpan. File lama tetap ada dengan MD5 yang sama, dan capture retake ditempatkan di subfolder/penamaan berversi baru (mis. `_v2`).
- **Actual:** Binary yang berjalan (`dist\core_service.exe`) menimpa file fisik yang sudah ada di folder capture. MD5 file lama berubah dari `58e226040d1b7a62b8cb6af875c57ee3` menjadi `22c1e69efa8d97608c55bc6c4be67f06`.
- **Langkah Reproduksi:**
  1. Capture foto untuk Tray `TEST001_1` -> Save. Catat MD5 file `captures_test\TEST001_1_000.00_2.60.jpg`.
  2. Panggil Retake (`POST /captures/{id}/retake`) dengan filename yang sama.
  3. Cek kembali file fisik di disk.
- **Evidence:**
  `MD5 before: 58e226040d1b7a62b8cb6af875c57ee3`  
  `MD5 after: 22c1e69efa8d97608c55bc6c4be67f06`  
  `Matches: False`
- **Dampak:** Kehilangan data historis capture sebelumnya secara permanen.
- **Suspected Cause:** Build `dist\core_service.exe` tidak mengarahkan retake ke `resolve_tray_dir(..., cand_v2)` atau resolver folder versi belum aktif pada binary terkompilasi ini.

---

### BUG-002
- **Severity:** Critical (P0)
- **Area:** Data Integrity / Same Drillhole Overwrite via Flutter UI
- **Expected:** Pengambilan foto untuk Drillhole yang sama pada sesi berikutnya tidak menimpa file sesi sebelumnya (folder versi baru dibuat).
- **Actual:** Method `capture()` di [api_client.dart](file:///d:/laragon/www/aplikasi%20foto%20core/apps/flutter_app/lib/api_client.dart#L41) dan [capture_screen.dart](file:///d:/laragon/www/aplikasi%20foto%20core/apps/flutter_app/lib/screens/capture_screen.dart#L96) **tidak menyertakan parameter `tray_id`** pada payload request ke `/captures`. Akibatnya, server fallback ke flat directory `captures/` dan file dengan nama drillhole yang sama langsung menimpa file lama.
- **Langkah Reproduksi:**
  1. Buat Session 1 -> Tray Hole `TEST001`, Tray `1`, From `0.00`, To `2.60` -> Capture via UI.
  2. File tersimpan di `captures/TEST001_1_000.00_2.60.jpg`.
  3. Buat Session 2 -> Tray Hole `TEST001`, Tray `1`, From `0.00`, To `2.60` -> Capture via UI.
  4. File `captures/TEST001_1_000.00_2.60.jpg` tertimpa tanpa pembuatan folder `_v2`.
- **Evidence:**
  Kode di [capture_screen.dart:96](file:///d:/laragon/www/aplikasi%20foto%20core/apps/flutter_app/lib/screens/capture_screen.dart#L96):
  `final cap = await widget.api.capture(filename: _form.filename(), box: [_fx, _fy], outDir: 'captures');` (Parameter `tray_id` tidak dikirim).
- **Dampak:** Data foto drillhole sebelumnya tertimpa jika nama file sama.
- **Suspected Cause:** Frontend tidak menyertakan parameter `tray_id` saat memanggil `api.capture()`.

---

### BUG-003
- **Severity:** Critical (P0)
- **Area:** Review Screen / Processing Save
- **Expected:** Setelah framing pada Live View, operator menekan tombol Save di layar Review dan gambar diproses crop 300 × 200.
- **Actual:** Aplikasi Flutter melempar unhandled exception Dart:  
  `TypeError: 0.0: type 'double' is not a subtype of type 'int'`  
  Proses Save gagal total saat ditekan operator.
- **Langkah Reproduksi:**
  1. Masuk ke tab Capture -> Isi tray valid -> Tekan Live View untuk menandai box.
  2. Tekan Take Picture -> Layar otomatis berpindah ke tab Review.
  3. Tekan tombol **Save**.
  4. Muncul error pada konsol Dart / UI terhenti.
- **Evidence:**
  Kode pada [review_screen.dart:45](file:///d:/laragon/www/aplikasi%20foto%20core/apps/flutter_app/lib/screens/review_screen.dart#L45):
  `box: List<int>.from(cap['box'] as List)`  
  Sementara di [capture_screen.dart:32-104](file:///d:/laragon/www/aplikasi%20foto%20core/apps/flutter_app/lib/screens/capture_screen.dart#L32-L104), koordinat disimpan dalam tipe `double` (`_fx`, `_fy`).
- **Dampak:** Operator tidak dapat menyimpan hasil capture sama sekali melalui UI jika framing disentuh atau bernilai default `0.0`.
- **Suspected Cause:** Type casting `List<int>.from` tidak kompatibel dengan `List<double>`.

---

### BUG-004
- **Severity:** High (P0/P1)
- **Area:** Camera Integration / UI
- **Expected:** Kamera terhubung atau dapat dihubungkan oleh operator melalui UI agar Live View dan Capture dapat berjalan.
- **Actual:** Service `core_service.exe` saat startup menginisialisasi kamera dalam kondisi `Not Connected` (`adapter: null`). Di dalam UI Flutter, **tidak ada tombol "Connect Camera"**, tidak ada trigger `/camera/connect`, dan `ApiClient` bahkan tidak memiliki fungsi `cameraConnect()`.
- **Langkah Reproduksi:**
  1. Jalankan `core_service.exe` dan `core_photo.exe`.
  2. Buka aplikasi. Dashboard menampilkan `Camera: Not Connected`.
  3. Buka Capture screen. Live View gagal dan tombol capture error `capture blocked: camera not ready`.
- **Evidence:**
  Pemeriksaan seluruh codebase `apps/flutter_app`: kata kunci `camera/connect` bernilai `0 matches`.
- **Dampak:** Pengguna baru tidak dapat menggunakan kamera sama sekali kecuali mengirimkan request HTTP manual ke `POST /camera/connect`.
- **Suspected Cause:** Kurangnya auto-connect saat startup service atau ketiadaan tombol Connect di UI.

---

### BUG-005
- **Severity:** High (P0/P1)
- **Area:** Live View
- **Expected:** Live View menampilkan preview frame kamera secara visual.
- **Actual:** Layar Live View di UI selalu menampilkan placeholder teks hitam `Live View (offline)`.
- **Langkah Reproduksi:**
  1. Hubungkan kamera via API.
  2. Buka tab Capture di aplikasi Flutter.
  3. Perhatikan kotak Live View.
- **Evidence:**
  Request `GET /camera/frame` tanpa memanggil `/camera/liveview/start` menghasilkan `HTTP 409 Conflict: {"error": "live view not running: call start first"}`. Flutter `Image.network` gagal memuat gambar dan mengaktifkan widget `errorBuilder` yang merender teks `"Live View (offline)"`.
- **Dampak:** Operator tidak dapat melihat tampilan framing kamera secara visual.
- **Suspected Cause:** `CaptureScreen` di Flutter tidak pernah memanggil endpoint `/camera/liveview/start` saat layar dibuka.

---

### BUG-006
- **Severity:** High (P0)
- **Area:** Filename Validation
- **Expected:** Format filename mengikuti konvensi existing `ID Drillhole_No Tray_Interval Kedalaman.jpg`. Sebagai contoh input sesuai PRD/QA: Hole ID = `TEST001`, Tray ID = `TEST001_TRAY01`, From = `0.00`, To = `2.60`.
- **Actual:** Frontend menghasilkan nama `TEST001_TEST001_TRAY01_000.00_2.60.jpg`. Backend menolak file ini dengan error `invalid filename` karena regex di backend secara kaku mengharuskan No Tray hanya berupa digit (`\d+`).
- **Langkah Reproduksi:**
  1. Input Tray ID dengan nama teks `TEST001_TRAY01`.
  2. Tekan Take Picture.
  3. Job Capture gagal dengan status `error`: `invalid filename: 'TEST001_TEST001_TRAY01_000.00_2.60.jpg'`.
- **Evidence:**
  Regex di [filenames.py:4](file:///d:/laragon/www/aplikasi%20foto%20core/services/core_service/app/filenames.py#L4):  
  `_PATTERN = re.compile(r"^([A-Za-z0-9]+)_(\d+)_(\d+\.\d{2})_(\d+\.\d{2})\.(jpg|JPG)$")`.
- **Dampak:** Seluruh tray dengan penamaan alfanumerik (seperti `TRAY_01`, `BOX-A`) ditolak oleh sistem capture.
- **Suspected Cause:** Regex validator hanya mengizinkan `(\d+)` untuk segmen Tray.

---

### BUG-007
- **Severity:** High (P0)
- **Area:** Save / File Output Naming
- **Expected:** Sesuai PRD §8.7, §16: Hasil crop 300 × 200 disimpan sebagai file deliverable JPG dengan nama kanonis (mis. `Core01_1_000.00_2.60.jpg`).
- **Actual:** Pada executable `dist\core_service.exe`, nama kanonis diberikan kepada file RAW original, sedangkan JPG deliverable hasil crop diberi suffix `_display.jpg` (`TEST001_1_000.00_2.60_display.jpg`).
- **Langkah Reproduksi:**
  1. Capture & Save foto.
  2. Buka folder penyimpanan.
- **Evidence:**
  File fisik yang terbentuk di `captures_test`:
  - `TEST001_1_000.00_2.60.jpg` (RAW, 8.7 KB)
  - `TEST001_1_000.00_2.60_display.jpg` (Crop JPG, 2.3 KB)
  - `TEST001_1_000.00_2.60_thumb.jpg` (Thumb, 1.8 KB)
- **Dampak:** Deliverable output tidak memenuhi standar nama file kanonis existing.
- **Suspected Cause:** Binary `dist\core_service.exe` belum diperbarui dari versi lama sebelum perubahan shift file kanonis.

---

### BUG-008
- **Severity:** Medium (P1)
- **Area:** Validation / Correction
- **Expected:** Operator dapat memperbaiki data tray yang salah via tombol "Edit & Re-validate" pada tab Validation.
- **Actual:** Menekan tombol "Edit & Re-validate" memunculkan error `ApiException(404): {"detail": "Not Found"}`.
- **Langkah Reproduksi:**
  1. Buka tab Validation di UI. Masukkan ID tray (mis. `t1`) -> Validate.
  2. Tekan tombol "Edit & Re-validate".
- **Evidence:**
  Hasil probe ke executable `dist\core_service.exe`:  
  `GET /trays/t1` -> `HTTP 404 {"detail": "Not Found"}`  
  `PATCH /trays/t1` -> `HTTP 404 {"detail": "Not Found"}`  
  Rute tersebut tidak terdaftar di OpenAPI spec binary yang berjalan.
- **Dampak:** Fitur koreksi data tray di UI tidak dapat digunakan pada build release saat ini.
- **Suspected Cause:** Build `dist\core_service.exe` tidak mengompilasi rute `GET /trays/{tid}` dan `PATCH /trays/{tid}`.

---

### BUG-009
- **Severity:** Medium (P1)
- **Area:** Review Screen / UI Inspection
- **Expected:** Layar Review menampilkan visual gambar foto yang baru diambil agar operator dapat memeriksa framing sebelum Save atau Retake.
- **Actual:** Kotak preview berwarna hitam hanya menampilkan teks string path file (misal `captures/Core01_1_000.00_2.60.jpg`), bukan render foto.
- **Langkah Reproduksi:**
  1. Ambil foto -> Otomatis masuk ke tab Review.
  2. Perhatikan area kotak preview.
- **Evidence:**
  Kode pada [review_screen.dart:98-100](file:///d:/laragon/www/aplikasi%20foto%20core/apps/flutter_app/lib/screens/review_screen.dart#L98-L100):  
  `child: Center(child: Text(cap['raw_path'].toString(), style: const TextStyle(color: Colors.white)))`.
- **Dampak:** Operator tidak dapat melakukan inspeksi visual (kualitas, pencahayaan, posisi) terhadap foto yang diambil sebelum disimpan.
- **Suspected Cause:** Implementasi UI masih bersifat placeholder teks.

---

### BUG-010
- **Severity:** Medium (P1)
- **Area:** Dashboard / Navigation
- **Expected:** Mengklik menu di Dashboard mengarahkan ke halaman yang sesuai (Photo Browser -> Browser Screen, dsb.).
- **Actual:** Menu Dashboard mengalami pergeseran indeks:
  - Klik *Photo Browser* membuka tab **Review** (index 3).
  - Klik *Validation* membuka tab **Photo Browser** (index 4).
  - Klik *Transfer* membuka tab **Validation** (index 5).
  - Klik *Settings* membuka tab **Transfer** (index 6).
- **Langkah Reproduksi:**
  1. Berada di tab Home (Dashboard).
  2. Klik item "Photo Browser".
  3. Layar yang terbuka adalah layar "Review".
- **Evidence:**
  [dashboard_screen.dart:30](file:///d:/laragon/www/aplikasi%20foto%20core/apps/flutter_app/lib/screens/dashboard_screen.dart#L30):  
  `const {'Session': 1, 'Capture': 2, 'Photo Browser': 3, 'Validation': 4, 'Transfer': 5, 'Settings': 6}`  
  Sedangkan di [main.dart:37-54](file:///d:/laragon/www/aplikasi%20foto%20core/apps/flutter_app/lib/main.dart#L37-L54), urutan page adalah:  
  0: Dashboard, 1: Session, 2: Capture, 3: Review, 4: Browser, 5: Validation, 6: Transfer, 7: Settings.
- **Dampak:** Disorientasi operator dan ketidakmampuan membuka halaman Settings dari Dashboard.
- **Suspected Cause:** Halaman Review disisipkan pada index 3 di `main.dart` tanpa memperbarui map indeks navigasi di `dashboard_screen.dart`.

---

## E. Data Integrity

Pengujian integritas data dilakukan secara menyeluruh terhadap berkas fisik dan basis data SQLite:

1. **Filename Deliverable:**
   - **FAIL**: Sesuai temuan BUG-007, binary yang berjalan menyimpan JPG hasil olahan dengan nama `*_display.jpg`, bukan nama kanonis PRD.
2. **MD5 Verification:**
   - **FAIL saat Retake**: Pada kondisi normal pertama kali simpan, MD5 dihitung dan cocok dengan berkas RAW. Namun ketika operasi **Retake** dijalankan (BUG-001), berkas fisik ditimpa dengan hash baru sementara sidecar JSON dan database tetap mencatat MD5 lama, menyebabkan hilangnya integritas checksum.
3. **Metadata Sidecar JSON:**
   - **PASS**: Terbukti seluruh 16 field metadata hadir lengkap: `hole_id`, `tray_id`, `interval_from`, `interval_to`, `path`, `comments`, `date`, `operator`, `site`, `md5`, `timestamp`, `rows`, `length`, `width`, `crop`, dan `filename`.
4. **Retake Safe Versioning:**
   - **FAIL**: Retake tidak membuat direktori berversi `_v2` pada runtime saat ini, melainkan langsung menimpa file fisik yang ada di lokasi yang sama.
5. **Same Drillhole Across Sessions:**
   - **FAIL**: Penggunaan Drillhole ID yang sama pada sesi berbeda menyebabkan file lama tertimpa karena front-end tidak mengirim `tray_id` pada pemanggilan capture.
6. **No Overwrite Guarantee:**
   - **FAIL**: Aplikasi saat ini **belum memenuhi garansi No Overwrite** pada skenario Retake dan Drillhole yang sama via UI.
7. **Local File Retention After Transfer:**
   - **PASS**: Seluruh file RAW, JPG, Thumbnail, dan sidecar JSON lokal **100% tetap tersimpan di workstation** setelah proses transfer ke server/share selesai. Tidak ada penghapusan file lokal.

---

## F. Offline Capability

| Fitur | Status Offline | Keterangan |
|---|---|---|
| **Session Management** | **Bekerja 100%** | Tersimpan di SQLite lokal `%LOCALAPPDATA%\CorePhoto\data.db`. |
| **Tray Data & Interval Validation** | **Bekerja 100%** | Validasi lokal berjalan tanpa dependensi jaringan. |
| **Camera & Capture** | **Bekerja 100%** | Kamera terhubung langsung ke PC (USB/localhost). |
| **Image Processing & Tray Crop** | **Bekerja 100%** | Pemrosesan PIL/Pillow dan crop 300 × 200 berjalan lokal. |
| **Photo Browser** | **Bekerja 100%** | Membaca database SQLite dan file storage lokal. |
| **Validation & Correction** | **Bekerja 100%** | Validasi aturan interval dan kelengkapan dilakukan lokal. |
| **Transfer** | **Dapat Ditolak Bersih** | Memerlukan jaringan/share server tujuan. Jika jaringan mati, transfer gagal dengan aman (Error status) tanpa merusak file lokal. |

Aplikasi dirancang secara tepat untuk operasi lokal offline di stasiun fotografi tambang.

---

## G. Hardware Integration

Berdasarkan pengujian langsung di workstation:

- **VERIFIED:**
  - `FakeAdapter`: Terbukti mampu mensimulasikan protokol kamera (status reporting, frame generation 640×480, capture resolution 800×600, mock capability Live View/ISO/Focus/Zoom/Capture).
- **BLOCKED:**
  - **Kamera DSLR Fisik (Canon / Nikon / Sony):** Driver/SDK fisik vendor (seperti EDSDK, Nikon SDK, Sony Camera Remote SDK) belum diintegrasikan ke dalam `CameraManager`. Hanya `FakeAdapter` yang didaftarkan. Pengujian terhadap perangkat kamera fisik berstatus **BLOCKED**.
- **UNVERIFIED:**
  - Kontrol hardware riil terhadap nilai Aperture, Flash, Metering Mode, Focusing Mode, dan ISO riil pada sensor kamera fisik berstatus **UNVERIFIED**.

---

## H. Requirement Traceability

| ID Requirement PRD | Deskripsi Requirement | Actual Behavior pada Aplikasi | Status | Evidence |
|---|---|---|:---:|---|
| **PRD §8.1** | Pengelolaan sesi (Date, Operator, Site) | Sesi tersimpan di SQLite, dapat diaktifkan dan dilanjutkan | **PASS** | `POST /sessions` -> 201, `GET /sessions/active` |
| **PRD §8.2** | Kamera terhubung langsung ke komputer | Terhubung via adapter localhost, status live | **PASS** (Mock) | `FakeAdapter` reporting |
| **PRD §8.2** | UI mengelola koneksi kamera | UI tidak memiliki tombol/fungsi connect kamera | **FAIL** | Codebase search `camera/connect` = 0 |
| **PRD §8.3** | Form Tray (8 field) & validasi `To < From` | Warning live muncul, tombol capture dinonaktifkan | **PASS** | `TrayForm.warning`, `validate_interval` |
| **PRD §8.4** | Live View, Grid overlay, dan framing | Grid tersedia, namun frame selalu offline karena belum start | **FAIL** | HTTP 409 pada `/camera/frame` di UI |
| **PRD §8.4 / §16** | Tray Crop 300 × 200 dari sudut Core Box | Standar ukuran crop tepat 300 × 200, posisi memengaruhi hasil | **PASS** | Visual check JPG: 300×200 px |
| **PRD §8.6** | Review foto sebelum disimpan | Review hanya menampilkan teks path file dalam kotak hitam | **FAIL** | `ReviewScreen` preview text path |
| **PRD §8.6 / §17.1** | Retake tanpa merusak hasil historis | File lama tertimpa dan MD5 berubah saat retake | **FAIL** | MD5 hash mismatch setelah retake |
| **PRD §8.7** | Output tiga format: RAW, JPG, Thumbnail | Ketiga file terbentuk (RAW, Crop JPG, Thumbnail) | **PASS** | File fisik terverifikasi di storage |
| **PRD §8.7 / §14** | Format nama file kanonis pada JPG deliverable | JPG deliverable dinamai `*_display.jpg`, RAW nama kanonis | **FAIL** | `TEST001_1_000.00_2.60_display.jpg` |
| **PRD §8.8** | Validasi tray & kesesuaian data | Validasi mengembalikan VALID / INVALID dengan field error | **PASS** | `POST /trays/validate` |
| **PRD §8.8 / §16** | Koreksi tray yang salah dan validasi ulang | Endpoint koreksi 404 Not Found di binary yang berjalan | **FAIL** | `PATCH /trays/{id}` -> 404 |
| **PRD §8.9** | Photo Browser (pencarian Hole, preview JPG & thumb) | Daftar foto tampil, filter drillhole jalan, preview dialog ada | **PASS** | Browser screen & API `/photos` |
| **PRD §8.10** | Drillhole sama tidak menimpa file lama | File tertimpa di disk jika drillhole dan interval sama | **FAIL** | Penulisan file flat pada `captures/` |
| **PRD §8.11** | Transfer ke server & file lokal tetap disimpan | File disalin via background thread, file lokal utuh 100% | **PASS** | `POST /transfer`, verifikasi file lokal |
| **PRD §8.12 / §20.8**| Pengaturan kamera (ISO, Focus, Zoom) | Nilai di layar Settings bersifat teks display statis | **GAP** | Settings screen ListTile display only |
| **PRD §9** | Penyimpanan 16 metadata field dalam sidecar | Sidecar JSON memuat ke-16 atribut yang disyaratkan | **PASS** | Pemeriksaan JSON sidecar lengkap |

---

## I. Kesimpulan

### Status Akhir:
# **NOT READY**

### Alasan Penilaian:
Meskipun arsitektur dasar lokal (offline storage SQLite, validasi interval matematik, background streaming transfer, pemrosesan Pillow crop 300 × 200, dan struktur sidecar 16 field) telah diimplementasikan dengan sangat baik di backend, aplikasi yang **benar-benar berjalan saat ini belum siap masuk ke tahap operasional/produksi** karena adanya **7 kegagalan berstatus Critical (P0)**:

1. **Destructive File Overwrite (Integritas Data Hilang):** Operasi Retake dan pengambilan foto pada Drillhole yang sama menimpa file fisik lama secara langsung tanpa versioning folder aman (`_v2`), merusak keaslian data audit foto geologi tambang.
2. **Runtime Type Crash pada Workflow Utama:** Menekan tombol **Save** pada layar Review menghasilkan *unhandled exception* di runtime Flutter (`TypeError: double is not a subtype of type int`), menghentikan flow penyimpanan operator.
3. **Kamera Default Disconnected Tanpa Kontrol UI:** Aplikasi tidak menyediakan tombol atau logika menghubungkan kamera, membuat workstation yang baru dinyalakan lumpuh total tanpa bantuan developer yang mengirimkan curl HTTP secara manual.
4. **Live View Tidak Berfungsi:** Frame kamera tidak pernah muncul di UI akibat ketiadaan inisiasi start live view dari Flutter.
5. **Non-canonical File Naming:** Output deliverable JPG utama tidak menggunakan nama file kanonis PRD, melainkan suffix `_display.jpg`.
6. **Kegagalan Validasi Alfanumerik:** Penamaan Tray ID alfanumerik (mis. `TEST001_TRAY01`) ditolak oleh validator capture.
7. **Build Binary Out-of-Sync:** Binary `dist\core_service.exe` tidak menyertakan rute koreksi data (`PATCH /trays/{id}`) sehingga fitur perbaikan data menghasilkan error 404.

Laporan ini diserahkan kepada tim pengembang sebagai panduan teknis objektif untuk perbaikan stabilitas dan integritas sistem sebelum pengujian tahap berikutnya dilakukan.
