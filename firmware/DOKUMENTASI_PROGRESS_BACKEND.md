# Dokumentasi Progress — Smart Locker: Backend & Firmware

> Dokumen ini merangkum apa yang sudah dikerjakan untuk sisi **backend
> server (Express + Firestore)**, **hosting (Render.com)**, dan
> **firmware ESP32** dari project Smart Locker IoT, dari awal sampai sesi
> kerja terakhir. Simpan sebagai catatan lanjutan untuk sesi berikutnya.

---

## 1. Ringkasan Proyek

Smart Locker adalah sistem penyewaan locker otomatis berbasis QR
dinamis dan web (tanpa akun permanen), dengan sisi internal berupa app
Flutter untuk Petugas Keamanan & Kebersihan.

Backend server berperan sebagai **single source of truth** untuk:

- Status tiap locker (`empty` / `occupied` / `needs_attention`)
- Sesi sewa (start, durasi, akhir)
- Kode unik sewa (disimpan ter-hash SHA-256)
- Token QR dinamis per locker (dirotasi saat locker kosong, dibekukan saat occupied)
- Antrian perintah `unlock` untuk firmware ESP32
- Push notification (FCM) ke app petugas
- Rate limiting percobaan kode salah
- Autentikasi petugas/admin pakai JWT
- Autentikasi device untuk firmware (device token)

Firmware ESP32 bertugas:

- Koneksi ke WiFi kampus + reconnect
- Sync state locker ke backend tiap 2 detik
- Eksekusi perintah unlock dari backend
- Baca sensor pintu (limit switch / reed magnet)
- Render QR dinamis ke layar TFT

**Peran user di project ini:** membangun backend server + firmware ESP32.

Dokumen sumber lengkap (sudah ada sebelumnya, tidak diulang di sini):

- `docs/API.md` — kontrak resmi endpoint
- `docs/DEVELOPMENT_GUIDE.md` — konsep, 5W1H, arsitektur, RAB
- `docs/SKPL_Smart_Locker_IoT_final.docx` — SKPL resmi
- `DOKUMENTASI_PROGRESS.md` — progress app Flutter petugas (sisi Reza)
- `firmware/smart_locker_firmware_documentation.md` — detail firmware

---

## 2. Keputusan Arsitektur

| Aspek                     | Keputusan                                  | Alasan                                                   |
| ------------------------- | ------------------------------------------ | -------------------------------------------------------- |
| Framework                 | **Express.js (Node.js)**                   | Ringan, banyak referensi, tidak butuh build step         |
| Database                  | **Firestore (Firebase)**                   | Free tier cukup, realtime, tidak perlu setup server DB   |
| Hosting                   | **Render.com (free tier)**                 | Tanpa kartu kredit untuk awal, auto-deploy dari GitHub   |
| Credential                | **Service Account Key** via env variable   | Karena backend jalan di luar infrastruktur Google        |
| Autentikasi pelanggan     | Tidak ada                                  | Sesuai konsep: tanpa akun permanen                       |
| Autentikasi admin/petugas | **JWT 7 hari**, tanpa refresh              | Cukup untuk prototipe kampus, simpel untuk app           |
| Autentikasi firmware      | **Device token** (header `X-Device-Token`) | Cegah akses tidak sah ke endpoint firmware               |
| Password storage          | **bcrypt (cost 10)**                       | Praktik baik untuk hashing password                      |
| Kode unik sewa            | **SHA-256 hash**                           | Kode asli hanya ditampilkan 1x, tidak bisa diambil ulang |
| Rate limiter              | **Firestore-based**                        | Konsisten di multi-instance, persist antar-restart       |
| **Token QR rotation**     | **In-memory** (RAM)                        | Hemat Firestore writes, hindari quota exceeded           |
| **Firmware ↔ backend**    | **`POST /sync`** (gabung poll + report)    | Hemat request, ESP32 lebih ringan                        |

**Kenapa tidak pakai Firebase Cloud Functions?**

Rencana awal backend di-deploy sebagai Firebase Cloud Functions. Tapi
`firebase deploy --only functions` gagal karena butuh paket Blaze
(pay-as-you-go) untuk mengaktifkan API Cloud Build. Solusi: pindah ke
Express server biasa yang di-hosting di Render, tetap akses Firestore
yang sama lewat service account key.

---

## 3. Endpoint yang Sudah Selesai

Semua endpoint di bawah ini sudah live di production dan sudah ditest.

### Batch 1 — Endpoint Pelanggan (Web)

| Endpoint                  | Method | Fungsi                                              | Status |
| ------------------------- | ------ | --------------------------------------------------- | ------ |
| `/api/lockers/:id/status` | GET    | Cek status locker (validasi token QR)               | ✅     |
| `/api/lockers/:id/rent`   | POST   | Sewa locker baru (generate kode unik, antri unlock) | ✅     |
| `/api/lockers/:id/access` | POST   | Buka ulang / akhiri sewa (validasi kode unik)       | ✅     |
| `/api/rentals/:id/status` | GET    | Cek status sesi & durasi berjalan                   | ✅     |

### Batch 2 — Endpoint Firmware (Lama) + Service Latar

| Endpoint                             | Method | Fungsi                                                   | Status |
| ------------------------------------ | ------ | -------------------------------------------------------- | ------ |
| `/api/firmware/:controllerId/poll`   | GET    | ESP32 ambil perintah unlock + token QR (masih berfungsi) | ✅     |
| `/api/firmware/:controllerId/report` | POST   | ESP32 lapor event `opened`/`closed` (masih berfungsi)    | ✅     |

**Service latar:**

- `qrTokenRotatorService` — rotasi token QR tiap 5 detik, **in-memory**
- `timeoutMonitorService` — deteksi pintu tidak tertutup > 2 menit → `needs_attention`
- `commandQueueService` — antrean perintah unlock (consume-once)

### Batch 3 — Endpoint Admin (App Petugas)

| Endpoint                         | Method | Fungsi                                     | Auth       | Status |
| -------------------------------- | ------ | ------------------------------------------ | ---------- | ------ |
| `/api/auth/login`                | POST   | Login petugas/admin                        | -          | ✅     |
| `/api/admin/lockers`             | GET    | List semua locker + status                 | Bearer JWT | ✅     |
| `/api/admin/lockers/:id/resolve` | POST   | Resolve locker `needs_attention` → `empty` | Bearer JWT | ✅     |
| `/api/admin/register-device`     | POST   | Daftarkan FCM token petugas                | -          | ✅     |

### Batch 4 — Rate Limiter + FCM

Service baru:

- `rateLimiterService` — batasi 5 percobaan kode salah per locker per 10 menit, lock 5 menit
- `fcmService` — kirim push notification ke semua device petugas saat locker jadi `needs_attention`

Diintegrasikan ke endpoint `/api/lockers/:id/access`.

### Batch 5 — Reports Endpoint

| Endpoint                     | Method | Fungsi                                     | Auth       | Status |
| ---------------------------- | ------ | ------------------------------------------ | ---------- | ------ |
| `/api/admin/reports/rentals` | GET    | Laporan sesi sewa + statistik (role admin) | Bearer JWT | ✅     |

Response field: `stats` (total_rentals, avg_duration_seconds, busiest_locker_id) dan `rentals` (dengan `no_hp` di-mask sebagian).

### Fase 1 — In-Memory Token Rotation (Fix Quota)

**Masalah:** Rotator token tulis Firestore 4 locker × 12×/menit = ~69.000 writes/hari. Limit free tier cuma 20.000/hari → quota exceeded.

**Solusi:** Token disimpan **di RAM backend**. Firestore cuma menyimpan data penting (status locker, rental, dll).

**Hasil:** Writes harian untuk rotasi turun ke **~0**. Kalau backend restart, token langsung regenerate otomatis.

### Fase 4 — Device Authentication

**Endpoint firmware sekarang wajib header `X-Device-Token`.**

| Endpoint                             | Method | Auth         | Status |
| ------------------------------------ | ------ | ------------ | ------ |
| `/api/firmware/:controllerId/poll`   | GET    | Device Token | ✅     |
| `/api/firmware/:controllerId/report` | POST   | Device Token | ✅     |
| `/api/firmware/:controllerId/sync`   | POST   | Device Token | ✅     |

**Cara kerja:**

- Setiap controller (`esp32_01`) punya `authToken` unik di Firestore collection `controllers`
- Token di-seed manual via `seedController.js`
- Middleware `deviceAuthMiddleware.js` cek header, cache 5 menit untuk hemat Firestore reads

### Fase 5 — Endpoint `/sync` (Gabungan Poll + Report)

**Endpoint baru:** `POST /api/firmware/:controllerId/sync`

**Request body:**

```json
{
  "lockers": [{ "index": 0, "door_open": false, "solenoid_on": false }]
}
```

**Response:**

```json
{
  "commands": [{ "locker_index": 0, "action": "unlock", "pulse_hold": true }],
  "qr_tokens": { "0": "abc123", "1": "def456" }
}
```

**Keuntungan:**

- ESP32 kirim 1 request per siklus (hemat ~50% bandwidth)
- Backend mendeteksi transisi pintu sendiri (state comparison)
- Logic sesi terpusat di backend
- `/poll` dan `/report` lama tetap berfungsi (backward compatibility)

---

## 4. Struktur Kode

```
backend-express/
├── server.js                        # entry point (Express + startScheduler + initTokenStore)
├── seed.js                          # seed 4 locker untuk testing
├── seedPetugas.js                   # seed akun admin & petugas1
├── seedController.js                # seed device auth token (tidak di-commit)
├── reset.js                         # reset state locker + rate_limits (dev only)
├── package.json
├── .gitignore
├── serviceAccountKey.json           # rahasia, tidak di-commit
└── src/
    ├── firebase.js                  # init Firestore
    ├── scheduler.js                 # cron rotasi token + timeout monitor
    ├── middleware/
    │   ├── authMiddleware.js        # requireAuth, requireRole (JWT admin)
    │   └── deviceAuthMiddleware.js # requireDeviceAuth (device token firmware)
    ├── routes/
    │   ├── auth.js                  # POST /login
    │   ├── admin.js                 # endpoint admin + reports + debug
    │   ├── lockers.js               # endpoint pelanggan (status, rent, access)
    │   ├── rentals.js               # endpoint sesi (rental status)
    │   └── firmware.js              # endpoint firmware (poll, report, sync)
    └── services/
        ├── uniqueCodeService.js     # generate + hash + verify kode unik
        ├── qrTokenService.js        # generate token QR
        ├── tokenStoreService.js     # in-memory token store (rotasi)
        ├── tokenStoreInit.js        # init token store dari Firestore
        ├── qrTokenRotatorService.js # job rotasi token (in-memory)
        ├── lockerStateStore.js      # in-memory state pintu (untuk /sync)
        ├── commandQueueService.js   # antrean perintah unlock
        ├── timeoutMonitorService.js # job deteksi pintu tidak tertutup
        ├── authService.js           # hash/verify password + JWT
        ├── rateLimiterService.js    # batasi percobaan kode salah
        ├── reportService.js         # laporan sesi + statistik
        └── fcmService.js            # kirim push notification
```

### Detail file penting (baru)

**`src/services/tokenStoreService.js`**
In-memory store untuk token QR per locker. Fungsi: `initLocker`, `setStatus`, `setFrozen`, `rotate`, `rotateAll`, `getLatestToken`, `isTokenValid`, `getAll`. Token valid 60 detik, histori max 15 token.

**`src/services/tokenStoreInit.js`**
Load semua locker dari Firestore saat server start. Kalau Firestore gagal (quota exceeded), fallback ke daftar statis (untuk dev). Retry tiap 60 detik.

**`src/services/lockerStateStore.js`**
In-memory state pintu + solenoid per locker. Dipakai untuk deteksi transisi di endpoint `/sync`.

**`src/middleware/deviceAuthMiddleware.js`**
Cek header `X-Device-Token` di endpoint `/firmware/*`. Cache token di memory 5 menit.

---

## 5. Setup Lokal

### Prasyarat

- Node.js v20+
- Akses Firebase Console project `smart-locker-project-45bac`
- Git

### Langkah

1. Masuk folder `backend-express`:

   ```powershell
   cd backend-express
   ```

2. Install dependency:

   ```powershell
   npm install
   ```

3. Ambil **service account key** dari Firebase Console:
   - Firebase Console → ⚙️ Project Settings → Service accounts → Generate new private key
   - Simpan sebagai `backend-express/serviceAccountKey.json`

4. Seed data:

   ```powershell
   node seed.js
   node seedPetugas.js
   node seedController.js
   ```

   - `seed.js`: 4 locker dengan token valid 1 jam
   - `seedPetugas.js`: akun `admin/admin123` dan `petugas1/petugas123`
   - `seedController.js`: device auth token untuk `esp32_01`

5. Jalankan server:
   ```powershell
   node server.js
   ```
   Harus muncul: `Server jalan di port 3000`, `[tokenStore] Initialized 4 lockers`, `[scheduler] started`

### Akun Testing

| Username   | Password     | Role    |
| ---------- | ------------ | ------- |
| `admin`    | `admin123`   | admin   |
| `petugas1` | `petugas123` | petugas |

⚠️ Ganti password ini di production sebelum demo.

### Device Token

Dari output `seedController.js`:

```
[seed] authToken: 70cd4fbd2fd930b1844d7dcff3bb9270
```

Simpan token ini di firmware `config.h` sebagai `DEVICE_TOKEN`. Untuk test manual via Thunder Client, kirim header `X-Device-Token`.

---

## 6. Deploy ke Render (Production)

**Base URL production:** `https://smart-locker-backend-a2ck.onrender.com`

### Konfigurasi Web Service di Render

| Field                           | Nilai                     |
| ------------------------------- | ------------------------- |
| Repository                      | `User404/Smart-locker`    |
| Branch                          | `feature/firmware`        |
| Root Directory                  | `backend-express`         |
| Runtime                         | Node                      |
| Build Command                   | `npm install`             |
| Start Command                   | `npm start`               |
| Instance Type                   | Free                      |
| Region                          | Singapore                 |
| Env: `FIREBASE_SERVICE_ACCOUNT` | isi JSON service account  |
| Env: `NODE_VERSION`             | `20`                      |
| Env: `JWT_SECRET`               | string random 48 karakter |

### Cara Deploy

Auto-deploy belum aktif. Setiap update kode:

1. Push ke GitHub
2. Dashboard Render → service `smart-locker-backend`
3. Klik **Manual Deploy** → **Clear build cache & deploy** (kalau ada file baru) atau **Deploy latest commit** (kalau cuma edit)
4. Tunggu 2–3 menit sampai status **Live**

**Kapan wajib Clear build cache?**

- Menambah file baru
- Ubah `package.json`
- Tambah route baru

**Kalau lupa clear cache saat ada file baru**, route baru tidak muncul (balas 404 HTML dari Express, bukan JSON).

---

## 7. Log Setup & Troubleshooting

Histori masalah & solusinya:

1. **`firebase deploy --only functions` gagal "must be on Blaze plan"`** — Cloud Functions butuh API Cloud Build yang cuma bisa diaktifkan di paket Blaze. Solusi: pindah ke Express server biasa + Render.

2. **`TypeError: Cannot read properties of undefined (reading 'cert')`** — `firebase-admin` v14 pakai API modular. Solusi: `const { initializeApp, cert } = require("firebase-admin/app")`.

3. **`Cannot find module '@google-cloud/firestore'` di Render** — sub-dependency tidak ke-install otomatis. Solusi: `npm install @google-cloud/firestore`.

4. **Render build cache stale** — commit baru tidak ke-deploy meski push sukses. Solusi: **Clear build cache & deploy**.

5. **Server lokal masih pakai route lama** — Node.js tidak auto-reload. Setelah edit, stop server (Ctrl+C) dan start ulang.

6. **`RPC failed; curl 35 Recv failure`** saat git push — masalah HTTP/2. Solusi: `git config --global http.version HTTP/1.1`.

7. **Token QR expire saat test production** — token cuma valid 60 detik. Untuk testing, `seed.js` kasih token berlaku 1 jam.

8. **`ReferenceError: checkLock is not defined`** — require rate limiter belum ada atau salah posisi.

9. **`LOCKER_NOT_OCCUPIED` saat test rate limiter** — timeout monitor ubah locker ke `needs_attention`. Solusi: ubah `TIMEOUT_MS` sementara untuk testing.

10. **`LOGIN 401` setelah ganti `JWT_SECRET` di Render** — token lama jadi invalid. Solusi: login ulang.

11. **404 HTML dari Express di production** — route tidak ter-register. Cek commit yang ter-deploy = commit terakhir, kalau ya → clear build cache.

12. **Typo command PowerShell** (misal `node server.jsnode server.js`) — cek perintah sebelum Enter.

13. **`8 RESOURCE_EXHAUSTED: Quota exceeded`** — Firestore free tier harian habis. Penyebab: rotator token tulis Firestore terlalu sering. Solusi: **Fase 1 (in-memory token rotation)** — token disimpan di RAM, tidak tulis Firestore lagi.

14. **`SyntaxError: Unexpected token '?'` di tokenStoreService.js** — kode `??` ketulis jadi `? ?` (ada spasi). Solusi: ganti `??` dengan if-else eksplisit.

15. **Watchdog trigger saat TFT belum terpasang** — firmware coba render QR ke TFT yang tidak ada, SPI blocking. Solusi: `ENABLE_TFT false` di `config.h` untuk dev mode.

16. **GPIO 34-39 flapping (pintu terbuka-tutup tanpa henti)** — pin input-only tidak punya internal pull-up. Solusi dev: `ENABLE_DOOR_SENSOR false`. Solusi hardware: resistor pull-up 10kΩ ke 3.3V.

17. **`[Sync] HTTP 404 Cannot POST /api/firmware/esp32_01/sync`** — endpoint `/sync` belum ke-commit/deploy. Solusi: commit backend, push, deploy Render.

18. **`401 INVALID_DEVICE_TOKEN` dengan token yang "sama"`** — 1 karakter hilang saat copy-paste token. Solusi: copy token dari Firestore Console (`controllers/esp32_01.authToken`), bandingkan karakter-per-karakter.

---

## 8. Status Saat Ini

**Backend:**

- [x] Setup hosting backend (Render.com) + Firestore
- [x] Batch 1: 4 endpoint pelanggan
- [x] Batch 2: 2 endpoint firmware + service latar
- [x] Batch 3: 4 endpoint admin (login JWT, list, resolve, register-device)
- [x] Batch 4: rate limiter + FCM
- [x] Batch 5: reports endpoint
- [x] Fase 1: in-memory token rotation (fix quota)
- [x] Fase 4: device auth token
- [x] Fase 5: endpoint `/sync`
- [x] Semua endpoint di-test di lokal & production
- [x] Service account key aman (tidak ke-commit)
- [x] JWT_SECRET ter-set di Render

**Firmware:**

- [x] `wifi_client` — connect + reconnect (tested)
- [x] `backend_poller` (sync mode) — tested end-to-end
- [x] `lock_control` — compile OK, belum test relay fisik
- [x] `door_sensor` — compile OK, tested via jumper
- [x] `event_reporter` — terintegrasi ke `/sync`
- [x] `tft_render` — compile OK, dry-run

**Belum:**

- [ ] Test end-to-end hardware fisik (butuh relay + solenoid + sensor + TFT dari Alfian)
- [x] Integrasi FCM di app Flutter petugas (Reza)
- [ ] Ganti password default admin/petugas1
- [ ] Merge `feature/firmware` ke `main` lewat Pull Request
- [x] Hapus endpoint debug (`/api/admin/debug/tokens`) — **selesai** (commit `d1733d1`)

## 9. Keputusan Desain

| Pertanyaan                                              | Keputusan                                           |
| ------------------------------------------------------- | --------------------------------------------------- |
| Akun admin/petugas: seed manual atau endpoint register? | **Seed manual** di Firestore (collection `petugas`) |
| Token login                                             | **JWT expire 7 hari**, tanpa refresh                |
| Filter tanggal di reports                               | **Tidak dulu**. Tampilkan semua.                    |
| `no_hp` di reports                                      | **Dimask sebagian** (`0812****89`)                  |
| Firmware endpoint                                       | **Device token** (header `X-Device-Token`)          |
| Firmware komunikasi                                     | **`POST /sync`** — gabungan poll + report           |
| Token QR storage                                        | **In-memory** (RAM), bukan Firestore                |
| QR validity                                             | 60 detik, rotasi 5 detik, histori 15 token          |

---

## 10. Langkah Selanjutnya

### Hardware Integration (menunggu Alfian rakit)

- Wiring relay 4-channel ke GPIO 25, 26, 27, 32
- Wiring sensor magnet/limit switch ke GPIO 34, 35, 36, 39 + **resistor pull-up 10kΩ**
- Wiring TFT ST7789 1.3" — SCLK=18, MOSI=23, CS=[4,13,14,33], DC=[16,17,21,22], BLK=19
- Solenoid 12V fail-secure + adaptor + diode flyback

### Integrasi FCM di App Flutter (Reza)

1. App ambil FCM token dari Firebase Messaging
2. App panggil `POST /api/admin/register-device`
3. Backend simpan di `petugas_devices`
4. Backend auto-kirim push saat locker jadi `needs_attention`

### Production Hardening

- Ganti password default `admin/admin123` dan `petugas1/petugas123`
- Hapus endpoint `/api/admin/debug/tokens`
- Set `ENABLE_TFT true` dan `ENABLE_DOOR_SENSOR true` di firmware production
- Set `BUILD_MODE_PRODUCTION` di firmware
- Audit `JWT_SECRET` (harus random)

---

## 11. Catatan untuk Sesi Berikutnya

- **`reset.js` dan `seedController.js` di-gitignore** — kalau clone repo di komputer baru, bikin sendiri atau pakai seed script
- **`serviceAccountKey.json` tidak ada di GitHub** — generate ulang dari Firebase Console
- **Auto-deploy Render belum aktif** — pakai manual deploy
- **Token QR di production seed berlaku 1 jam** — untuk testing, bukan spec final (spec: 60 detik)
- **`docs/API.md` adalah kontrak resmi** — setiap perubahan endpoint, update dokumen dulu
- **Firmware dan backend harus sinkron** — kalau ganti endpoint firmware, update `config.h` juga

---

## 12. Referensi Penting

- **Repo:** https://github.com/UUser404/Smart-locker
- **Branch:** `feature/firmware`
- **Production URL:** https://smart-locker-backend-a2ck.onrender.com
- **Dashboard Render:** https://dashboard.render.com
- **Firebase Console:** https://console.firebase.google.com/project/smart-locker-project-45bac
- **Kontrak API:** `docs/API.md`
- **SKPL:** `docs/SKPL_Smart_Locker_IoT_final.docx`
- **Firmware docs:** `firmware/smart_locker_firmware_documentation.md`
