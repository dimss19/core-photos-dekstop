~# PRD — Aplikasi Pengambilan Foto Core

**Versi:** 1.0  
**Dokumen:** Spesifikasi untuk AI Coding Agent  
**Status:** Implementation Specification

---

# 1. Project Overview

Bangun aplikasi desktop untuk mendukung proses pengambilan dan pengelolaan foto drill core.

Aplikasi digunakan operator untuk:

1. membuat atau membuka Session;
2. menghubungkan kamera ke komputer;
3. memasukkan data tray;
4. melihat Live View;
5. melakukan framing;
6. mengambil foto;
7. melakukan Review dan Retake;
8. menyimpan RAW;
9. menghasilkan JPG dan Thumbnail melalui Tray Crop;
10. melakukan Validation;
11. menyimpan hasil secara lokal;
12. melihat kembali foto melalui Photo Browser;
13. melakukan Transfer hasil pekerjaan ke Server.

Aplikasi harus dapat menjalankan workflow capture dan processing secara lokal tanpa koneksi jaringan.

---

# 2. Tujuan

Tujuan aplikasi:

- Mempermudah operator dalam melakukan dokumentasi foto drill core.
- Menjaga hubungan antara foto dengan Session, Drillhole, Tray, dan interval kedalaman.
- Memastikan foto dapat diperiksa sebelum disimpan.
- Menghasilkan output foto yang konsisten.
- Membantu operator menemukan kesalahan melalui Validation.
- Memungkinkan pekerjaan capture tetap berjalan ketika jaringan tidak tersedia.
- Menyediakan proses transfer hasil pekerjaan ke Server ketika koneksi tersedia.

---

# 3. Pengguna

Pengguna utama adalah operator yang melakukan pengambilan foto core pada photography station.

Kondisi penggunaan:

```text
Camera
   ↓
Computer / Workstation
   ↓
Photography Station
   ↓
Core Tray
```

Kamera terhubung langsung ke komputer.

---

# 4. Core Workflow

Workflow utama:

```text
Session
   ↓
Camera Ready
   ↓
Tray Data
   ↓
Interval Validation
   ↓
Live View
   ↓
Framing
   ↓
Capture
   ↓
Review
   ├── Retake ──→ Capture
   │
   └── Save
        ↓
     Processing
        ↓
       RAW
        ↓
    Tray Crop
      ├── JPG
      └── Thumbnail
        ↓
     Validation
      ├── Invalid → Correction → Validation
      │
      └── Valid
           ↓
       Tray Complete
           ↓
      More Tray?
       ├── Yes → Tray Data
       └── No
            ↓
         Transfer
            ↓
    Transfer Validation
            ↓
          Done
```

---

# 5. Session

## 5.1 Session Data

Session minimal memiliki:

- Date
- Name / Operator
- Site

## 5.2 Session Actions

Operator dapat:

- Create Session
- Open Session
- Continue Session

Session aktif menjadi konteks untuk proses capture.

---

# 6. Camera Integration

## 6.1 Connection

Kamera terhubung langsung ke komputer.

Workflow:

```text
Connect Camera
      ↓
Camera Detected?
  ├── No → Show Error → Fix Connection → Detect Again
  └── Yes
       ↓
   Camera Ready
```

Kamera disiapkan ketika proses capture dimulai dan tetap digunakan untuk Tray berikutnya selama koneksi masih tersedia.

## 6.2 Camera Status

Aplikasi harus dapat menampilkan status kamera, minimal:

- Connected / Ready
- Not Connected
- Error

Jika kamera terputus saat workflow berjalan, aplikasi harus menampilkan kondisi tersebut dan mencegah proses yang membutuhkan kamera sampai kamera kembali tersedia.

## 6.3 Live View

Aplikasi menyediakan Live View dari kamera.

Live View digunakan untuk:

- melihat posisi core tray;
- memastikan framing;
- membantu operator sebelum Capture.

## 6.4 Camera Settings

Pengaturan kamera yang diperlukan:

### ISO / Brightness

Kecerahan biasanya disesuaikan melalui ISO.

Acuan penggunaan sekitar **+1200** untuk mendapatkan hasil yang mendekati warna asli sample.

Implementasikan sesuai representasi yang digunakan oleh API kamera.

### Focus

Focus dapat dikontrol melalui aplikasi apabila didukung oleh kamera/API.

Pada penggunaan normal, Focus dapat disesuaikan manual ketika kamera dipasang.

### Zoom

Zoom dapat dikontrol melalui aplikasi apabila didukung oleh kamera/API.

Pada penggunaan normal, Zoom dapat disesuaikan manual ketika kamera dipasang.

Jika kamera tidak mendukung suatu fungsi, aplikasi harus menangani kondisi tersebut tanpa crash.

---

# 7. Tray Data

Operator memasukkan:

- Hole ID / Drillhole ID
- Tray ID
- Core Interval From
- Core Interval To
- Tray Rows
- Tray Length
- Tray Width
- Comments

Data Tray tetap terkait dengan foto yang diambil selama proses Tray tersebut.

---

# 8. Interval Validation

Business rule:

```text
Core Interval From
        +
Core Interval To
        ↓
     To < From?
      /     \
    YES      NO
     ↓        ↓
 Warning    Valid
     ↓
Capture Disabled
```

Jika:

```text
To < From
```

maka:

1. aplikasi memberikan warning;
2. tombol **Take Picture / Capture** disabled;
3. operator memperbaiki nilai interval;
4. setelah valid, Capture kembali dapat digunakan.

Jangan mengizinkan Capture ketika kondisi `To < From`.

---

# 9. Live View dan Framing

Setelah data Tray valid:

1. Operator meletakkan tray/core pada photography station.
2. Operator membuka Live View.
3. Operator memastikan posisi tray.
4. Operator menyesuaikan framing.
5. Operator dapat menggunakan Grid dan Zoom.
6. Operator melakukan Capture.

---

# 10. Capture

Workflow:

```text
Tray Data Valid
      ↓
Live View
      ↓
Framing
      ↓
Capture
      ↓
Photo Captured
      ↓
Review
```

Saat Capture berhasil:

- foto diterima dari kamera;
- foto dikaitkan dengan Session dan Tray aktif;
- hasil ditampilkan untuk Review.

---

# 11. Review dan Retake

Setelah Capture:

```text
Capture
   ↓
Display Result
   ↓
Review
   ↓
Suitable?
 ├── No → Retake → Capture
 └── Yes → Save
```

Jika Retake:

- operator dapat mengambil foto kembali;
- metadata Tray tetap digunakan;
- foto hasil Retake menjadi hasil yang digunakan untuk proses berikutnya.

---

# 12. Image Processing

Setelah Save:

```text
RAW Photo
    ↓
Tray Crop Area
   ├── JPG
   └── Thumbnail
```

## 12.1 RAW

RAW adalah file original dari kamera.

Requirement:

- simpan file original;
- jangan melakukan perubahan terhadap file RAW sebagai sumber original.

## 12.2 JPG

JPG dibuat berdasarkan area Tray Crop dari Raw Foto.

## 12.3 Thumbnail

Thumbnail dibuat berdasarkan area Tray Crop dari Raw Foto.

Thumbnail digunakan untuk kebutuhan preview dan Photo Browser.

---

# 13. Tray Crop

Tray Crop menentukan area dari Raw Foto yang digunakan untuk menghasilkan JPG dan Thumbnail.

Standar:

```text
Tray Crop = 300 × 200
```

Patokan:

```text
Sudut Box Core
```

Konsep:

```text
Raw Photo
    ↓
┌─────────────────┐
│                 │
│    Tray Crop    │
│      300×200    │
│                 │
└─────────────────┘
    ↓
JPG + Thumbnail
```

Implementasi crop harus mempertahankan hubungan dengan posisi Box Core.

Jangan menambahkan aturan crop lain yang tidak tercantum dalam requirement.

---

# 14. Filename

Format filename menggunakan standar:

```text
ID Drillhole_No Tray_Interval Kedalaman
```

Contoh:

```text
Core01_1_000.00_2.60.jpg
```

Format existing harus dipertahankan.

Buat fungsi parser/validator filename terpisah dari UI.

Jangan mengubah format filename tanpa requirement baru.

---

# 15. Metadata

Foto harus dapat dikaitkan dengan informasi Session dan Tray.

Metadata yang digunakan dapat mencakup:

- Hole ID
- Tray ID
- Core Interval From
- Core Interval To
- Path
- Comments
- Date
- Name
- Site
- MD5
- Timestamp
- Tray Rows
- Tray Length
- Tray Width
- Tray Crop

Struktur penyimpanan metadata harus dibuat konsisten dan mudah digunakan oleh Photo Browser dan proses Transfer.

---

# 16. Validation

Validation dilakukan setelah foto dan output diproses.

Status:

```text
VALID
INVALID
```

Jika Invalid:

```text
Validation
    ↓
Invalid
    ↓
Show Problem
    ↓
Correction
    ↓
Validation Again
```

Validation minimal mencakup:

- interval;
- filename;
- data yang diperlukan untuk proses foto.

Jangan menambahkan business rule lain tanpa requirement.

---

# 17. Local Storage

Aplikasi harus menyimpan hasil pekerjaan secara lokal.

Capture dan Processing tidak membutuhkan koneksi jaringan.

File lokal:

- RAW;
- JPG;
- Thumbnail;
- metadata.

File lokal tetap tersedia setelah proses Transfer.

## 17.1 Folder Baru untuk Drillhole yang Sama

Jika terdapat foto berikutnya dengan Drillhole ID yang sama, aplikasi membuat folder file baru.

Tujuan:

- mencegah file lama tertimpa;
- menjaga pekerjaan lama tetap tersedia;
- memisahkan pekerjaan baru dari pekerjaan sebelumnya.

Jangan melakukan overwrite otomatis terhadap hasil pekerjaan lama.

---

# 18. Photo Browser

Photo Browser digunakan untuk melihat kembali foto yang sudah tersimpan.

Minimal menyediakan:

- pencarian/filter Drillhole;
- informasi Tray;
- informasi interval;
- Thumbnail;
- preview foto.

Photo Browser bekerja berdasarkan data lokal.

---

# 19. Transfer

Transfer merupakan proses terpisah dari capture.

Workflow:

```text
Capture Selesai
      ↓
Open Transfer
      ↓
Select Session/Data
      ↓
Check Server Connection
      ↓
Server Accessible?
   ┌──┴──┐
  No    Yes
   ↓      ↓
 Error   Transfer
   ↓      ↓
 Retry   Validate Transfer
           ↓
       Success?
        ┌─┴─┐
       No  Yes
       ↓    ↓
     Error Success
       ↓
     Retry
```

## 19.1 Transfer Requirements

- Operator dapat memilih Session/data.
- Sistem memeriksa koneksi Server.
- Sistem melakukan transfer.
- Sistem menampilkan progress/status.
- Sistem melakukan validasi hasil transfer.
- Jika gagal, operator dapat Retry.
- File lokal tetap disimpan.
- Transfer tidak boleh menghapus hasil lokal.

---

# 20. UI Screens

## 20.1 Dashboard / Home

Menampilkan:

- Session aktif;
- status kamera;
- akses Capture;
- akses Photo Browser;
- akses Validation;
- akses Transfer;
- informasi storage jika diperlukan.

## 20.2 Session

Menampilkan:

- Date;
- Operator;
- Site.

Action:

- Create;
- Open;
- Continue.

## 20.3 Capture Tray

Menampilkan:

- Tray Data;
- Live View;
- Grid;
- Zoom;
- framing;
- Camera Status;
- Capture.

## 20.4 Review

Menampilkan:

- hasil foto;
- metadata Tray;
- Save;
- Retake.

## 20.5 Photo Browser

Menampilkan:

- search/filter;
- daftar foto;
- Thumbnail;
- informasi foto;
- preview.

## 20.6 Validation

Menampilkan:

- status validation;
- masalah yang ditemukan;
- detail error/warning;
- action untuk memperbaiki.

## 20.7 Transfer

Menampilkan:

- Session/data;
- Server status;
- progress;
- transfer status;
- validation status;
- Retry.

## 20.8 Settings

Menampilkan konfigurasi aplikasi dan camera settings yang tersedia.

---

# 21. Application State

Gunakan state workflow yang jelas.

```text
SESSION_CREATED
      ↓
CAMERA_READY
      ↓
TRAY_INPUT
      ↓
READY_TO_CAPTURE
      ↓
CAPTURING
      ↓
REVIEWING
      ├── RETAKE → READY_TO_CAPTURE
      └── SAVE
            ↓
        PROCESSING
            ↓
        VALIDATING
         ├── INVALID → CORRECTION → VALIDATING
         └── VALID
                ↓
           TRAY_COMPLETED
                ↓
          NEXT_TRAY / SESSION_DONE
```

Prerequisite harus dipenuhi sebelum state berubah.

Contoh:

```text
To < From
    ↓
Tidak boleh masuk CAPTURING
```

---

# 22. Error Handling

## Camera

Handle:

- camera tidak terdeteksi;
- camera disconnected;
- capture gagal;
- setting tidak didukung.

## Input

Handle:

- data belum lengkap;
- interval invalid;
- filename invalid.

## Storage

Handle:

- disk penuh;
- permission denied;
- file write gagal;
- folder creation gagal;
- konflik file/folder.

## Processing

Handle:

- RAW tidak dapat dibaca;
- crop gagal;
- JPG generation gagal;
- Thumbnail generation gagal.

## Transfer

Handle:

- Server tidak dapat diakses;
- koneksi terputus;
- transfer gagal;
- validation transfer gagal.

Error message harus jelas dan memberikan tindakan yang dapat dilakukan operator bila memungkinkan.

---

# 23. Non-Functional Requirements

## Reliability

- Jangan kehilangan metadata ketika Retake.
- Jangan overwrite file lama secara tidak sengaja.
- Failure pada satu proses harus dapat dipulihkan jika memungkinkan.

## Offline Operation

Capture, Processing, Review, Validation, dan Local Storage harus dapat berjalan tanpa network.

## Performance

UI tidak boleh freeze selama:

- Capture;
- image processing;
- JPG generation;
- Thumbnail generation;
- file operation;
- Transfer.

Gunakan asynchronous/background processing bila diperlukan.

## Maintainability

Pisahkan tanggung jawab:

```text
UI
Camera
Capture
Processing
Validation
Storage
Photo Browser
Transfer
```

## Logging

Sediakan logging untuk:

- camera connection;
- capture;
- processing;
- validation;
- file operation;
- transfer.

---

# 24. Acceptance Criteria

## Session

- [ ] Create Session berfungsi.
- [ ] Open/Continue Session berfungsi.
- [ ] Date, Operator, dan Site tersimpan.

## Camera

- [ ] Kamera dapat dideteksi.
- [ ] Status kamera ditampilkan.
- [ ] Live View dapat digunakan.
- [ ] Capture dapat dilakukan.
- [ ] Disconnect/error ditangani tanpa crash.

## Tray

- [ ] Data Tray dapat dimasukkan.
- [ ] Interval dapat divalidasi.
- [ ] `To < From` menghasilkan warning.
- [ ] Capture disabled ketika `To < From`.

## Capture

- [ ] Foto dapat diambil.
- [ ] Hasil foto dapat direview.
- [ ] Retake dapat dilakukan.
- [ ] Metadata Tray tetap digunakan setelah Retake.

## Processing

- [ ] RAW tersimpan.
- [ ] JPG dihasilkan dari Tray Crop.
- [ ] Thumbnail dihasilkan dari Tray Crop.
- [ ] Tray Crop menggunakan standar 300×200.
- [ ] Patokan crop menggunakan sudut Box Core.

## Filename

- [ ] Filename mengikuti format existing.
- [ ] Filename dapat divalidasi.

## Local Storage

- [ ] Capture dapat berjalan tanpa network.
- [ ] Processing dapat berjalan tanpa network.
- [ ] File lokal tetap tersedia setelah Transfer.
- [ ] Drillhole ID yang sama dapat menggunakan folder baru.
- [ ] File lama tidak tertimpa secara tidak sengaja.

## Photo Browser

- [ ] Foto dapat dicari/filter.
- [ ] Thumbnail dapat ditampilkan.
- [ ] Foto dapat dibuka dalam preview.

## Transfer

- [ ] Koneksi Server dapat diperiksa.
- [ ] Transfer dapat dijalankan.
- [ ] Progress/status ditampilkan.
- [ ] Hasil transfer dapat divalidasi.
- [ ] Transfer gagal dapat di-retry.
- [ ] File lokal tidak dihapus.

---

# 25. Testing Scenarios

## Scenario A — Normal Capture

```text
Create Session
→ Connect Camera
→ Enter Tray
→ Validate
→ Live View
→ Capture
→ Review
→ Save
→ Processing
→ Validation
→ Tray Complete
```

Expected:

- RAW tersedia;
- JPG tersedia;
- Thumbnail tersedia;
- metadata terkait tersedia.

## Scenario B — Retake

```text
Capture
→ Review
→ Tidak Sesuai
→ Retake
→ Capture
→ Review
→ Save
```

Expected:

- metadata Tray tetap benar;
- hasil Retake digunakan untuk processing.

## Scenario C — Invalid Interval

Input:

```text
From = 20
To = 10
```

Expected:

```text
Warning
Capture Disabled
```

Setelah:

```text
From = 10
To = 20
```

Expected:

```text
Capture Enabled
```

## Scenario D — Offline Capture

Network dimatikan.

Expected:

- camera tetap dapat digunakan;
- Capture tetap dapat dilakukan;
- Processing tetap dapat dilakukan;
- Validation tetap dapat dilakukan;
- file tersimpan lokal.

## Scenario E — Drillhole ID Sama

Pekerjaan pertama:

```text
Drillhole A
→ Folder A
```

Pekerjaan berikutnya:

```text
Drillhole A
→ Folder Baru
```

Expected:

- folder lama tetap aman;
- file lama tidak tertimpa.

## Scenario F — Transfer Failure

```text
Transfer
→ Server Unreachable
→ Error
→ Retry
```

Expected:

- error ditampilkan;
- data lokal tetap aman.

## Scenario G — Successful Transfer

```text
Transfer
→ Copy
→ Validate
→ Success
```

Expected:

- status berhasil;
- file lokal tetap tersedia.

---

# 26. Development Priority

## P0 — Core Workflow

Implementasikan terlebih dahulu:

- Session;
- Camera Connection;
- Camera Status;
- Tray Data;
- Interval Validation;
- Live View;
- Capture;
- Review;
- Retake;
- RAW Storage;
- Tray Crop;
- JPG;
- Thumbnail;
- Local Storage.

## P1 — Operational Features

Setelah P0 stabil:

- Filename Validation;
- Validation UI;
- Photo Browser;
- Camera Settings;
- Transfer;
- Transfer Validation;
- Retry.

## P2 — UX Improvements

Setelah P0 dan P1 stabil:

- UI polish;
- additional filtering;
- convenience features;
- performance improvements.

Jangan mengerjakan P2 sebelum P0 dan P1 stabil.

---

# 27. Development Rules

1. Jangan membuat fitur yang tidak diperlukan untuk workflow.
2. Jangan membuat asumsi terhadap requirement yang belum ditentukan.
3. Jika requirement ambigu dan mempengaruhi business logic, tandai:

```text
TODO: NEEDS CONFIRMATION
```

4. Jangan mengubah format filename.
5. Jangan melakukan overwrite terhadap file lama secara otomatis.
6. Jangan membuat Capture tersedia ketika interval invalid.
7. Jangan membuat Processing bergantung pada network.
8. Jangan membuat Transfer menghapus file lokal.
9. Jangan membuat UI freeze selama operasi kamera atau image processing.
10. Semua business rule harus dapat diuji secara independen dari UI.
11. Prioritaskan workflow P0 sebelum fitur tambahan.

---

# 28. Definition of Done

Sebuah fitur dianggap selesai apabila:

- implementasi sesuai requirement;
- workflow state benar;
- error handling tersedia;
- tidak ada accidental overwrite;
- dapat berjalan secara lokal;
- dapat diuji;
- acceptance criteria terkait terpenuhi;
- tidak menyebabkan regression pada workflow yang sudah selesai;
- logging tersedia untuk proses penting.

---

# 29. Final Product Flow

```text
Session
   ↓
Camera Ready
   ↓
Tray Data
   ↓
Interval Validation
   ↓
Live View
   ↓
Framing
   ↓
Capture
   ↓
Review
   ├── Retake ──→ Capture
   │
   └── Save
        ↓
      RAW
        ↓
    Tray Crop
      ├── JPG
      └── Thumbnail
        ↓
     Validation
      ├── Invalid → Correction → Validation
      │
      └── Valid
           ↓
       Tray Complete
           ↓
      More Tray?
       ├── Yes → Tray Data
       └── No
            ↓
         Transfer
            ↓
    Transfer Validation
            ↓
          Done
```

---

**End of PRD**
