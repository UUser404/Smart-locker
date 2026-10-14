# Smart Locker IoT

Sistem penyewaan locker otomatis berbasis IoT dengan **2 sisi berbeda**: sisi **pelanggan** sepenuhnya berbasis web (tanpa akun, tanpa install apa pun), dan sisi **internal Petugas Keamanan & Kebersihan** berupa app Android (Flutter) untuk memantau & menangani locker di lapangan.

**Alur pelanggan (web, scan QR dinamis di dalam web):**

1. User melihat locker kosong → buka halaman web di HP-nya, halaman langsung minta izin kamera untuk **scan QR di layar locker** (berganti tiap 5 detik selama locker kosong; bukan lagi lewat kamera bawaan HP membuka link statis).
2. Web decode QR (berisi `locker_id` + token yang berotasi berkala) dan validasi ke backend, lalu menampilkan form singkat: **nama & nomor HP** (tanpa akun permanen).
3. Setelah submit, sistem memberi **kode unik 1x lihat** (dengan tombol copy) yang wajib disimpan sendiri oleh user, lalu locker langsung terbuka dan sesi sewa dimulai.
4. Model sesinya seperti **parkir**: tidak ada durasi ditentukan di awal, timer mulai jalan begitu locker dibuka, dan total durasi baru dihitung saat sesi diakhiri.
5. Locker otomatis terkunci lagi lewat **sensor magnet** yang mendeteksi pintu tertutup (solenoid fail-secure).
6. Untuk ambil barang: user **scan ulang QR di layar locker yang sama** — QR-nya tidak berubah sejak locker mulai disewa (dibekukan selama sesi aktif) → masukkan kode unik → pilih **"Buka & Lanjut Sewa"** atau **"Ambil Barang & Akhiri Sewa"**.

**Alur Petugas Keamanan & Kebersihan (app Flutter):**

7. Petugas memantau status semua locker lewat dashboard di app.
8. Kalau ada locker berstatus **"perlu perhatian"** (pintu tidak tertutup > 2 menit), app mengirim **notifikasi push** ke HP petugas.
9. Petugas turun ke lapangan, cek fisik locker, lalu tekan tombol **resolve** di app setelah beres.

Dibangun sebagai project pembelajaran IoT (kontrol solenoid, koordinasi backend-firmware-web-app), dengan skala prototipe awal **4 unit locker** di lingkungan kampus.

---

## 📊 Update Progress — 14 Oktober 2026

| Komponen                           |          Status          | Detail                                                         |
| ---------------------------------- | :----------------------: | -------------------------------------------------------------- |
| Backend Express (Batch 1-5)        |      ✅ **Selesai**      | Semua endpoint live di Render.com                              |
| Firmware ESP32                     |  ✅ **Selesai (basic)**  | WiFi client, poller, lock control, door sensor, event reporter |
| App Flutter — Dashboard Petugas    |      ✅ **Selesai**      | List locker, resolve, auto-refresh, FCM                        |
| App Flutter — Dashboard Admin      |      ✅ **Selesai**      | Tab Analitik + Riwayat, statistik, durasi adaptif              |
| FCM Notification                   | ✅ **Teruji end-to-end** | Notif push masuk ke HP petugas saat locker `needs_attention`   |
| Web Pelanggan                      |    ⏳ **In Progress**    | HTML/CSS/JS statis; perlu verifikasi fungsional                |
| Integrasi fisik (rakitan hardware) |    ⏳ **In Progress**    | Menunggu rakitan fisik dari Alfian                             |

📌 **Referensi**: Lihat [`docs/DOKUMENTASI_TESTING_FCM.md`](docs/DOKUMENTASI_TESTING_FCM.md) untuk detail testing FCM.

---

## Struktur Repo

.
├── firmware/ # Kode ESP32 (PlatformIO project)
│ ├── DOKUMENTASI_PROGRESS_BACKEND.md
│ └── smart-locker/
│ ├── platformio.ini
│ └── src/ # wifi_client, backend_poller, lock_control, door_sensor, event_reporter
│
├── backend-express/ # ⭐ Server API AKTIF (Express.js) — di-hosting di Render.com
│ ├── server.js # Entry point
│ ├── seed.js # Seed 4 locker untuk testing
│ ├── seedPetugas.js # Seed akun admin & petugas1
│ └── src/
│ ├── firebase.js # Firebase Admin SDK init
│ ├── scheduler.js # Cron: rotasi QR token + timeout monitor
│ ├── middleware/
│ │ ├── authMiddleware.js # JWT verify
│ │ └── deviceAuthMiddleware.js # ESP32 device auth
│ ├── routes/
│ │ ├── auth.js # POST /api/auth/login
│ │ ├── admin.js # Lockers, resolve, register-device, reports
│ │ ├── lockers.js # Status, rent, access (pelanggan)
│ │ ├── rentals.js # Sesi rental
│ │ └── firmware.js # Poll + report (ESP32)
│ └── services/
│ ├── fcmService.js # Kirim FCM ke petugas
│ ├── timeoutMonitorService.js # Deteksi pintu tidak tertutup > 2 menit
│ ├── qrTokenService.js # Generate & validasi QR token
│ ├── qrTokenRotatorService.js # Rotasi token tiap 5 detik
│ ├── commandQueueService.js # Antrian perintah unlock
│ ├── rateLimiterService.js # Batasi percobaan kode salah
│ ├── uniqueCodeService.js # Generate kode unik + hash SHA-256
│ ├── authService.js # bcrypt + JWT
│ ├── reportService.js # Laporan rentals
│ ├── tokenStoreService.js # In-memory token store
│ ├── tokenStoreInit.js # Init token store dari Firestore
│ └── lockerStateStore.js # In-memory locker state
│
├── backend/ # ⚠️ LEGACY — Firebase Cloud Functions (tidak dipakai)
│
├── mprojectapp/ # ⭐ App Android (Flutter) untuk Petugas & Admin
│ ├── pubspec.yaml
│ ├── firebase.json
│ ├── android/ # Config Android + google-services.json
│ ├── lib/
│ │ ├── main.dart # Entry + startup gate
│ │ ├── firebase_options.dart # Auto-generated FlutterFire
│ │ ├── models/
│ │ │ ├── locker.dart
│ │ │ ├── rental_record.dart
│ │ │ └── session.dart
│ │ ├── screens/
│ │ │ ├── login_screen.dart
│ │ │ ├── dashboard_screen.dart # Petugas
│ │ │ ├── admin_home_screen.dart # Container (bottom nav)
│ │ │ ├── admin_analytics_screen.dart # Tab 1: statistik
│ │ │ ├── admin_history_screen.dart # Tab 2: riwayat
│ │ │ └── petugas_id_screen.dart
│ │ ├── services/
│ │ │ ├── api_service.dart # HTTP ke Express + JWT
│ │ │ ├── auth_service.dart # Login/logout + session persist
│ │ │ └── fcm_service.dart # Firebase Cloud Messaging
│ │ ├── utils/
│ │ │ └── duration_formatter.dart # Format adaptif: "5h 8j", "2j 15m"
│ │ └── widgets/
│ │ └── dashboard_widgets.dart
│ └── web/
│ └── public/ # ⚠️ Halaman web pelanggan (HTML/CSS/JS statis)
│ ├── index.html
│ ├── script.js
│ └── style.css
│
├── hardware/ # Wiring, RAB, foto rakitan fisik
│ ├── documentation.md
│ ├── RAB PROJECT SMART LOCKER.xlsx
│ └── (foto rakitan — progress)
│
└── docs/ # Dokumentasi konsep, kontrak API, hasil elisitasi
├── API.md
├── DEVELOPMENT_GUIDE.md
├── DOKUMENTASI_TESTING_FCM.md # Testing FCM end-to-end (14 Okt 2026)
├── SKPL Smart Locker IoT-final.docx
├── dokumentasi flutter/
│ ├── DOKUMENTASI_PROGRESS.md
│ └── DOKUMEN_FLUTTER_FIRESTORE-EXPRESS.md
└── elisitasi/
├── Berita Acara Wawancara.docx
├── Wawancara IT Jaringan Kampus.docx
├── Wawancara Keamanan Kebersihan.docx
├── Wawancara Pengelola Aset Kampus.docx
├── Wawancara Pengguna Akhir.docx
└── Hasil Elisitasi/

text

### ⚠️ Catatan Penting

> **Backend ada 2 folder:**
>
> - **`backend-express/`** — **AKTIF**. Server Express.js yang di-deploy di Render.com. **Semua development backend selanjutnya di sini.**
> - **`backend/`** — **LEGACY**. Firebase Cloud Functions, ditinggalkan karena butuh paket Blaze (pay-as-you-go). Hanya untuk history.
>
> Backend dev: **fokus ke `backend-express/`**.

> **Web pelanggan** ada di `mprojectapp/web/public/` (di dalam project Flutter) tapi di-serve terpisah. Tidak pakai Flutter Web — murni HTML/CSS/JS statis.

---

## Tim & Pembagian Tugas

Ringkasan cepat:

| Nama   | Scope                  | Folder yang Dipegang                 |
| ------ | ---------------------- | ------------------------------------ |
| Alfian | Hardware & Elektronika | `hardware/`                          |
| Galuh  | Backend & Firmware     | `firmware/`, `backend-express/`      |
| Reza   | Web & App Petugas      | `mprojectapp/` (app + `web/public/`) |

Detail tugas per orang:

### Alfian — Hardware & Elektronika

- [ ] Pengadaan komponen sesuai `hardware/RAB.xlsx` (ESP32, relay, solenoid, sensor magnet, adaptor, dll)
- [ ] Wiring relay + solenoid untuk 4 locker (fail-secure)
- [ ] Pasang & kalibrasi sensor magnet (reed switch) di tiap pintu
- [ ] Desain jalur daya: adaptor 12V → terminal block → (relay/solenoid) + (step-down 5V → ESP32), termasuk flyback diode
- [ ] Rakit casing/mekanik ke lemari 4 pintu 2 susun
- [ ] Buat wiring diagram (`hardware/wiring_diagram.png`)
- [ ] Dokumentasi foto progres rakitan (`hardware/photos/`)
- [ ] Kumpulkan datasheet komponen (`hardware/datasheets/`)

### Galuh — Backend & Firmware

**Firmware (`firmware/smart-locker/src/`):**

- [x] `wifi_client` — koneksi ESP32 ke WiFi kampus (STA mode)
- [x] `backend_poller` — polling ke backend tiap 2 detik, eksekusi perintah unlock
- [x] `lock_control` — kontrol relay/solenoid per locker (index 0-3)
- [x] `door_sensor` — baca sensor magnet + debounce, deteksi opened/closed
- [x] `event_reporter` — kirim laporan perubahan status pintu ke backend
- [x] `tft_render` — render QR token di layar TFT IPS

**Backend (`backend-express/src/`):**

- [x] Routes: `auth`, `lockers` (status/rent/access), `rentals` (status sesi), `firmware` (poll/report), `admin` (dashboard/resolve/register-device/reports)
- [x] Service `uniqueCodeService` — generate kode unik + hashing SHA-256
- [x] Service `commandQueueService` — antrian perintah unlock per locker
- [x] Service `qrTokenService` + `qrTokenRotatorService` — generate & rotasi token QR
- [x] Service `timeoutMonitorService` — job cek locker "terbuka > 2 menit"
- [x] Service `rateLimiterService` — batasi percobaan kode salah
- [x] Service `fcmService` — integrasi push notification (FCM) ke app petugas
- [x] Service `authService` — bcrypt + JWT
- [x] Service `reportService` — laporan rentals + statistik
- [x] Database Firestore + hosting di Render.com
- [x] `docs/API.md` up-to-date
- [x] **FCM teruji end-to-end** ✅

### Reza — Web & App Petugas

**Web pelanggan (`mprojectapp/web/public/`):**

- [ ] `index.html` + scanner QR (kamera browser, decode `locker_id` + token)
- [ ] Form sewa (nama & no HP) + tampilan kode unik (dengan tombol copy)
- [ ] Halaman input kode unik + pilihan "Lanjut Sewa" / "Akhiri Sewa"
- [ ] `script.js` — scan QR, validasi token, fetch status locker, submit form, polling durasi berjalan tiap 3 detik, tangani token kedaluwarsa
- [ ] `style.css` — styling halaman web

**App Flutter petugas & admin (`mprojectapp/lib/`):**

- [x] **Model**: `Locker`, `RentalRecord`, `AuthSession` + `duration_formatter` (format adaptif "5h 8j")
- [x] **Service**: `ApiService` (HTTP + JWT), `AuthService` (session persist), `FcmService` (FCM)
- [x] **Screen Petugas**: `dashboard_screen` — list locker, resolve, auto-refresh saat resume, polling 10 detik
- [x] **Screen Admin**: `admin_home_screen` (bottom nav) + `admin_analytics_screen` (statistik + status locker) + `admin_history_screen` (riwayat + filter)
- [x] **Login**: `login_screen` — JWT auth via Express
- [x] **FCM**: register token, foreground handler, background tap, terminated handling
- [x] **Auto-refresh**: `WidgetsBindingObserver` untuk refresh saat app kembali dari background
- [x] **Resolve locker**: dialog konfirmasi → POST ke Express → auto-refresh

---

## Timeline & Jadwal Kerja

Estimasi untuk durasi project **1 semester (~14 minggu)** — **update terakhir 14 Oktober 2026**.

| Minggu | Fokus Kegiatan                                                       | PIC           | Status |
| ------ | -------------------------------------------------------------------- | ------------- | :----: |
| 1      | Riset & finalisasi konsep                                            | Semua         |   ✅   |
| 2      | Pelaksanaan wawancara 4 stakeholder + JAD dengan dosen pengampu      | Semua         |   ✅   |
| 3      | Pengadaan komponen & alat sesuai RAB                                 | Alfian        |   ⏳   |
| 3      | Setup skeleton project backend (routes, models, database)            | Galuh         |   ✅   |
| 4      | Wiring dasar: 1 relay + 1 solenoid + 1 sensor magnet (bench test)    | Alfian, Galuh |   ⏳   |
| 4      | Setup hosting backend supaya bisa diakses internet                   | Galuh         |   ✅   |
| 5      | Firmware: `wifi_client`, `backend_poller`, `lock_control`            | Galuh         |   ✅   |
| 5      | Desain awal halaman web pelanggan (wireframe/tampilan)               | Reza          |   ⏳   |
| 6      | Firmware: `door_sensor`, `event_reporter`                            | Galuh         |   ✅   |
| 6      | Web: form sewa (nama & no HP) + integrasi ke endpoint `/rent`        | Reza          |   ⏳   |
| 7      | Backend: `unique_code`, `command_queue`, `rate_limiter`              | Galuh         |   ✅   |
| 7      | Web: tampilan kode unik + halaman input kode unik (`/access`)        | Reza          |   ⏳   |
| 8      | Backend: `timeout_monitor` + integrasi push notification (FCM)       | Galuh         |   ✅   |
| 8      | Mulai app Flutter petugas: setup project + dashboard awal            | Reza          |   ✅   |
| 9      | Wiring & pemasangan ke 4 unit locker sekaligus                       | Alfian        |   ⏳   |
| 9      | App Flutter: tombol resolve + pendaftaran token FCM                  | Reza          |   ✅   |
| 10     | **Integrasi end-to-end**: scan → sewa → buka → tutup → sesi tercatat | Semua         |   ⏳   |
| 11     | Uji 4 locker sekaligus + race condition + notifikasi ke app petugas  | Semua         |   ⏳   |
| 12     | Rakit casing/mekanik fisik ke lemari                                 | Alfian        |   ⏳   |
| 12     | Uji skenario tepi: timeout, kode salah berkali-kali (rate limit)     | Galuh, Reza   |   ⏳   |
| 13     | Simulasi penggunaan oleh orang awam + perbaikan bug dari temuan      | Semua         |   ⏳   |
| 14     | Dokumentasi akhir, persiapan demo, deploy prototipe                  | Semua         |   ⏳   |

**Legend**: ✅ Selesai · ⏳ In Progress · ⬜ Belum Mulai

---

Kontrak endpoint HTTP antara backend, firmware, web, dan app didokumentasikan di [`docs/API.md`](docs/API.md) — **selalu update dokumen ini kalau ada perubahan endpoint**, supaya bagian lain tidak break.

---

## Arsitektur Singkat

- **Backend server (hosting internet):** single source of truth untuk status tiap locker (kosong/disewa/perlu perhatian), sesi sewa, dan kode unik. Di-deploy di Render.com, bisa diakses dari mana saja lewat internet.
- **Firmware (ESP32 per unit locker):** karena backend di-hosting di internet sementara ESP32 ada di jaringan lokal kampus, **ESP32 yang polling ke backend** secara berkala (bukan backend yang memanggil ESP32 langsung) untuk cek ada perintah buka atau tidak, sekaligus melaporkan status sensor magnet (pintu terbuka/tertutup).
- **Web (pelanggan, scan QR dinamis di dalam web):** halaman langsung buka kamera untuk scan QR di layar locker (bukan lagi lewat kamera bawaan HP membuka link statis), lalu form sewa singkat (nama & no HP), tampilan kode unik, halaman input kode unik untuk ambil barang. Tidak ada dashboard di sini — murni alur transaksi pelanggan.
- **App Flutter (internal, Petugas Keamanan & Kebersihan):** dashboard status semua locker, tombol resolve untuk locker "perlu perhatian", dan push notification real-time saat ada locker bermasalah. Dipilih Flutter (bukan web) khusus di sisi ini karena butuh notifikasi push yang jauh lebih mudah diimplementasikan lewat app native.
- **FCM (Firebase Cloud Messaging):** notifikasi push dikirim dari backend Express ke semua HP petugas terdaftar saat locker jadi `needs_attention`. **Teruji end-to-end pada 14 Oktober 2026** — lihat [`docs/DOKUMENTASI_TESTING_FCM.md`](docs/DOKUMENTASI_TESTING_FCM.md).
- **Tanpa akun permanen (sisi pelanggan):** identitas user cuma nama + no HP per sesi, diverifikasi lewat kode unik yang di-generate sekali per sesi sewa.
- **Auto-lock:** sensor magnet (reed switch) mendeteksi pintu tertutup → itu yang memicu backend menandai locker terkunci kembali (atau menyelesaikan sesi, tergantung pilihan user saat itu).
- **Mitigasi pintu tidak tertutup:** kalau setelah dibuka pintu tidak terdeteksi tertutup dalam 2 menit, locker otomatis ditandai **"perlu perhatian"**, memicu push notification ke app petugas, dan tidak bisa disewa sampai di-resolve manual.

Detail lengkap ada di [`docs/DEVELOPMENT_GUIDE.md`](docs/DEVELOPMENT_GUIDE.md).

---

## Cara Kerja Branch

- `main` — kode stabil & sudah teruji
- `feature/firmware-*` — pengembangan firmware ESP32
- `feature/backend-*` — pengembangan server API
- `feature/web-*` — pengembangan halaman web (user & dashboard petugas)
- `feature/hardware-*` — dokumentasi wiring, kalibrasi, casing locker
- `feature/flutter-*` — pengembangan app Flutter petugas & admin

Merge ke `main` lewat Pull Request, bukan push langsung.

---

## Cara Menjalankan (Development)

### Backend Express (local)

```bash
cd backend-express
npm install
# Setup serviceAccountKey.json dari Firebase Console
# Setup .env dengan JWT_SECRET
node server.js
# Server jalan di http://localhost:3000
Flutter App
bash
cd mprojectapp
flutter pub get
flutter run
# Login: admin/admin123 atau petugas1/petugas123
Firmware ESP32
bash
cd firmware/smart-locker
# Buka di VS Code + PlatformIO extension
pio run --target upload
Web Pelanggan
Buka mprojectapp/web/public/index.html di browser (atau via local server).

Endpoint Penting (Production)
Endpoint	URL
Base API	https://smart-locker-backend-a2ck.onrender.com/api
Login	POST /auth/login
List Lockers (admin/petugas)	GET /admin/lockers (Bearer JWT)
Resolve Locker	POST /admin/lockers/:id/resolve (Bearer JWT)
Reports	GET /admin/reports/rentals (Bearer JWT, admin only)
Register FCM Device	POST /admin/register-device
Firmware Poll	GET /firmware/:controllerId/poll
Firmware Report	POST /firmware/:controllerId/report
Detail lengkap: docs/API.md

Akun Testing
Username	Password	Role
admin	admin123	admin
petugas1	petugas123	petugas
⚠️ Ganti password ini sebelum demo production!

Tracking Progress
Gunakan tab Issues dan Projects (kanban: To Do / In Progress / Done) di repo ini untuk tracking task per orang.
```
