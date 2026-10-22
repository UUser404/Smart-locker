# Dokumentasi Progress — Smart Locker: Backend & Firmware

> Dokumen ini merangkum apa yang sudah dikerjakan untuk sisi **backend server (Express + Firestore)**, **hosting (Render.com)**, dan **firmware ESP32** dari project Smart Locker IoT, dari awal sampai sesi kerja terakhir. Simpan sebagai catatan lanjutan untuk sesi berikutnya.

---

## 1. Ringkasan Proyek

Smart Locker adalah sistem penyewaan locker otomatis berbasis QR dinamis dan web (tanpa akun permanen), dengan sisi internal berupa app Flutter untuk Petugas Keamanan & Kebersihan.

**Skala prototype:** **2 locker** (`locker_01`, `locker_02`) dalam 1 unit lemari 2 pintu, dikendalikan 1 unit ESP32. Firmware tetap mendukung hingga 4 locker di level arsitektur (array pin sudah disiapkan), tapi `ACTIVE_LOCKERS` di-set 2.

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
- `docs/DESAIN_NOTIFIKASI.md` — desain notifikasi (tingkat, jenis peringatan, channel)
- `docs/DEVELOPMENT_GUIDE.md` — konsep, 5W1H, arsitektur, RAB
- `docs/SKPL Smart Locker IoT-final.docx` — SKPL resmi
- `DOKUMENTASI_PROGRESS.md` — progress app Flutter petugas (sisi Reza)
- `firmware/smart_locker_firmware_documentation.md` — detail firmware
- `firmware/HARDWARE_WIRING_GUIDE.md` — panduan wiring untuk tim hardware

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
Rencana awal backend di-deploy sebagai Firebase Cloud Functions. Tapi `firebase deploy --only functions` gagal karena butuh paket Blaze (pay-as-you-go) untuk mengaktifkan API Cloud Build. Solusi: pindah ke Express server biasa yang di-hosting di Render, tetap akses Firestore yang sama lewat service account key.

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

| Endpoint                         | Method | Fungsi                                       | Auth       | Status             |
| -------------------------------- | ------ | -------------------------------------------- | ---------- | ------------------ |
| `/api/auth/login`                | POST   | Login petugas/admin                          | -          | ✅                 |
| `/api/admin/lockers`             | GET    | List semua locker + status                   | Bearer JWT | ✅                 |
| `/api/admin/lockers/:id/resolve` | POST   | Resolve locker `needs_attention` → `empty`   | Bearer JWT | ✅                 |
| `/api/admin/register-device`     | POST   | Daftarkan FCM token petugas (+ catch-up)     | -          | ✅                 |
| `/api/admin/unregister-device`   | POST   | Hapus FCM token petugas saat logout (Fase 7) | Bearer JWT | ⏳ menunggu deploy |

### Batch 4 — Rate Limiter + FCM

Service baru:

- `rateLimiterService` — batasi 5 percobaan kode salah per locker per 10 menit, lock 5 menit
- `fcmService` — kirim push notification ke semua device petugas saat locker jadi `needs_attention` (notif awal, reminder berkala, dan catch-up — lihat Fase 7)

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
| Endpoint | Method | Auth | Status |
| --- | --- | --- | --- |
| `/api/firmware/:controllerId/poll` | GET | Device Token | ✅ |
| `/api/firmware/:controllerId/report` | POST | Device Token | ✅ |
| `/api/firmware/:controllerId/sync` | POST | Device Token | ✅ |

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

### Fase 6 — Anti Alarm Fatigue (FCM Polish)

Mengacu pada materi PBP 6 tentang mencegah alarm fatigue:

- ~~**Jeda (cooldown)**: max 1 notif per locker per 10 menit~~ — **digantikan di Fase 7** (throttle reminder 60 detik)
- **Collapse key**: `locker_{lockerId}` — menggabungkan pesan yang belum terkirim ke device (untuk menggantikan notif di tray dibutuhkan `tag`, lihat Fase 7)
- **Time to Live (TTL)**: target 30 menit — notif basi tidak dikirim (kode saat ini 1 jam, `ttl = 60*60*1000` — belum disamakan)
- **Prioritas tinggi**: mode hemat daya Android tetap kirim
- **Isi dinamis**: durasi terbuka dihitung real-time ("pintu terbuka sejak 5 menit lalu")
- **Channel Android**: `smart_locker_alert` (sound + vibrate) — dipakai untuk notif awal & catch-up; reminder memakai `smart_locker_reminder` (lihat Fase 7)
- **Reset state**: saat petugas resolve locker, `resetCooldown()` menghapus timestamp throttle locker itu supaya masalah baru langsung dinotifikasi — tetap dipakai di Fase 7 (yang di-reset sekarang throttle reminder, bukan cooldown 10 menit)

**Test (Fase 6, sebelum cooldown dihapus):**

- `sent=3, failed=0` — kirim ke 3 device petugas berhasil
- `skip (cooldown, 598s lagi)` — panggilan kedua di-skip dalam 10 menit
- `cooldown di-reset` → `sent=3, failed=0` — reset bekerja

### Fase 7 — Reminder Berkala, Catch-up & Unregister

**Masalah:**

1. Setelah anti alarm-fatigue (cooldown 10 menit), petugas bisa **lupa** locker yang masih `needs_attention` karena tidak ada pengingat.
2. Petugas yang baru login (atau device offline) **tidak mendapat notifikasi** untuk locker bermasalah yang terjadi saat dia tidak aktif.
3. Token FCM petugas yang sudah logout masih tersimpan di `petugas_devices`, sehingga device itu tetap menerima notif.

**Solusi:**

**A. Reminder berkala 1 menit (accordion):**

- Cooldown 10 menit **dihapus**, diganti throttle `REMINDER_THROTTLE_MS` = **50 detik** per locker (sengaja di bawah interval scheduler 60 detik; kalau sama, jitter latency Firestore membuat reminder ter-skip satu tick dan efektif jadi tiap 2 menit).
- Scheduler baru (`REMINDER_INTERVAL_MS = 60s`) → `remindNeedsAttention()`.
- Setiap kiriman memakai `collapseKey = locker_{id}` (menggabungkan pesan belum terkirim), `android.notification.tag = locker_{id}` (**kunci accordion di tray**: notif baru menggantikan yang lama — body ter-update, durasi naik) dan `apns-collapse-id = locker_{id}` (iOS). `collapseKey` saja tidak cukup untuk accordion di tray.
- Reminder memakai channel `smart_locker_reminder` (low importance, silent) → tidak bunyi tiap menit.
- Berhenti otomatis saat `status != "needs_attention"` (dicek sebelum kirim).
- Reminder memakai prioritas normal (`android.priority = "normal"`, `apns-priority = 5`); notif awal dan catch-up prioritas high.
- `data.mode` bernilai `initial`, `reminder`, atau `catchup`.
- Timestamp throttle (`lastNotifiedAt`) hanya diperbarui kalau minimal 1 device sukses menerima; di-reset saat resolve via `resetCooldown()`.

**B. Catch-up saat login:**

- `POST /admin/register-device` → setelah set doc, panggil `catchUpForDevice(token)` (fire-and-forget).
- `catchUpForDevice()` query locker `needs_attention`, kirim FCM ke token yang baru register (channel alert, bunyi sekali).
- Frontend: `DashboardScreen._checkCatchUpSnackbars()` menampilkan snackbar in-app untuk locker `needs_attention` yang belum di-snackbar pada sesi itu.

**C. Unregister saat logout:**

- Endpoint baru `POST /admin/unregister-device` (JWT, role apa saja) menghapus doc `petugas_devices/{fcm_token}`. Idempotent.
- Kalau JWT expired saat logout, unregister gagal 401; token yatim dibersihkan otomatis oleh _defensive cleanup_ di `fcmService.js` saat FCM melaporkan `registration-token-not-registered`.

**Hasil yang diharapkan:**

- Petugas diingatkan tiap 1 menit (silent) sampai locker di-resolve.
- Petugas yang baru login langsung tahu ada locker bermasalah.
- Tidak ada notif menumpuk — accordion 1 slot per locker.
- Device yang sudah logout tidak menerima notif lagi.

**Log yang diharapkan saat uji** (belum diuji di production):

- `[fcm] locker_01 (initial): sent=3, failed=0` — notif awal bunyi
- `[fcm] locker_01 (reminder): sent=3, failed=0` — 60 detik kemudian, silent
- `[fcm catchup] 1 notif terkirim ke token xxx...` — saat login ulang
- `[fcm] locker_01: skip (status bukan needs_attention)` — setelah resolve
- `[fcm] tidak ada device terdaftar, skip` — setelah logout lalu trigger
- `[reminder tick] <ISO time>` dan `[reminder done] processed=N` — tiap 60 detik, tanda scheduler hidup (meski tidak ada locker)
- `[fcm reminder] query found N locker(s): ...` — hasil query locker `needs_attention`
- `[fcm] GAGAL (mode) token xxx: <kode> — <pesan>` — alasan kegagalan per token (ditambahkan 21 Okt untuk debugging)

**Temuan uji pertama (21 Okt 2026, status locker diubah manual di Firestore):**

- Notif awal muncul di HP petugas. Reminder tiap 1 menit **belum muncul** — masih di-debug (menunggu log Render).
- Bug ditemukan dan diperbaiki di `fcmService.js`: throttle 60 detik bentrok dengan interval scheduler 60 detik (jadi 50 detik); `setOnlyAlertOnce` bukan field FCM v1 (dihapus, diduga membuat request ditolak `INVALID_ARGUMENT` — belum terkonfirmasi di log); accordion di tray butuh `tag`, bukan hanya `collapseKey`.
- Bug di app Flutter: `Gagal resolve: Bad state` — lihat dokumen Flutter section 9.

> **Deploy:** ada route dan service baru → di Render wajib **Clear build cache & deploy** (lihat section 6).

---

## 4. Struktur Kode

```text
backend-express/
├── server.js                        # entry point (Express + startScheduler + initTokenStore)
├── seed.js                          # seed locker untuk testing
├── seedPetugas.js                   # seed akun admin & petugas1
├── seedController.js                # seed device auth token (tidak di-commit)
├── reset.js                         # reset state locker + rate_limits (dev only)
├── package.json
├── .gitignore
├── serviceAccountKey.json           # rahasia, tidak di-commit
└── src/
    ├── firebase.js                  # init Firestore
    ├── scheduler.js                 # cron rotasi token + timeout monitor + reminder needs_attention
    ├── middleware/
    │   ├── authMiddleware.js        # requireAuth, requireRole (JWT admin)
    │   └── deviceAuthMiddleware.js # requireDeviceAuth (device token firmware)
    ├── routes/
    │   ├── auth.js                  # POST /login
    │   ├── admin.js                 # endpoint admin + reports
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
        └── fcmService.js            # push notification: awal, reminder, catch-up
```

### Detail File Penting (Baru)

- `src/services/tokenStoreService.js`: In-memory store untuk token QR per locker. Fungsi: `initLocker`, `setStatus`, `setFrozen`, `rotate`, `rotateAll`, `getLatestToken`, `isTokenValid`, `getAll`. Token valid 60 detik, histori max 15 token.
- `src/services/tokenStoreInit.js`: Load semua locker dari Firestore saat server start. Kalau Firestore gagal (quota exceeded), fallback ke daftar statis (untuk dev). Retry tiap 60 detik.
- `src/services/lockerStateStore.js`: In-memory state pintu + solenoid per locker. Dipakai untuk deteksi transisi di endpoint `/sync`.
- `src/services/fcmService.js`: `notifyNeedsAttention()` (notif awal), `remindNeedsAttention()` (reminder tiap 60 detik, dipanggil scheduler), `catchUpForDevice(token)` (catch-up saat register-device), plus defensive cleanup token yatim (`registration-token-not-registered`).
- `src/middleware/deviceAuthMiddleware.js`: Cek header `X-Device-Token` di endpoint `/firmware/*`. Cache token di memory 5 menit.

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
3. Ambil service account key dari Firebase Console:
   - Firebase Console → ⚙️ Project Settings → Service accounts → Generate new private key
   - Simpan sebagai `backend-express/serviceAccountKey.json`
4. Seed data:

   ```powershell
   node seed.js
   node seedPetugas.js
   node seedController.js
   ```

   - `seed.js`: 2 locker dengan token valid 1 jam
   - `seedPetugas.js`: akun `admin/admin123` dan `petugas1/petugas123`
   - `seedController.js`: device auth token untuk `esp32_01`

5. Jalankan server:
   ```powershell
   node server.js
   ```
   Harus muncul: `Server jalan di port 3000`, `[tokenStore] Initialized 2 lockers`, `[scheduler] started`.

### Akun Testing

| Username   | Password     | Role    |
| ---------- | ------------ | ------- |
| `admin`    | `admin123`   | admin   |
| `petugas1` | `petugas123` | petugas |

⚠️ Ganti password ini di production sebelum demo.

### Device Token

Dari output `seedController.js`:

```text
[seed] authToken: <DEVICE_TOKEN>
```

Simpan token ini di firmware `config.h` sebagai `DEVICE_TOKEN`. Untuk test manual via Thunder Client, kirim header `X-Device-Token`.

> Jangan menulis token asli di dokumen atau commit. Ambil dari output seed atau dari Firestore (`controllers/esp32_01.authToken`).

---

## 6. Deploy ke Render (Production)

- **Base URL production:** `https://smart-locker-backend-a2ck.onrender.com`

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
  _(Kalau lupa clear cache saat ada file baru, route baru tidak muncul: balas 404 HTML dari Express, bukan JSON)._

---

## 7. Log Setup & Troubleshooting

Histori masalah & solusinya:

1. `firebase deploy --only functions` gagal `"must be on Blaze plan"` — Cloud Functions butuh API Cloud Build yang cuma bisa diaktifkan di paket Blaze. Solusi: pindah ke Express server biasa + Render.
2. `TypeError: Cannot read properties of undefined (reading 'cert')` — firebase-admin v14 pakai API modular. Solusi: `const { initializeApp, cert } = require("firebase-admin/app")`.
3. `Cannot find module '@google-cloud/firestore'` di Render — sub-dependency tidak ke-install otomatis. Solusi: `npm install @google-cloud/firestore`.
4. Render build cache stale — commit baru tidak ke-deploy meski push sukses. Solusi: Clear build cache & deploy.
5. Server lokal masih pakai route lama — Node.js tidak auto-reload. Setelah edit, stop server (`Ctrl+C`) dan start ulang.
6. `RPC failed; curl 35 Recv failure` saat `git push` — masalah HTTP/2. Solusi: `git config --global http.version HTTP/1.1`.
7. Token QR expire saat test production — token cuma valid 60 detik. Untuk testing, `seed.js` kasih token berlaku 1 jam.
8. `ReferenceError: checkLock is not defined` — require rate limiter belum ada atau salah posisi.
9. `LOCKER_NOT_OCCUPIED` saat test rate limiter — timeout monitor ubah locker ke `needs_attention`. Solusi: ubah `TIMEOUT_MS` sementara untuk testing.
10. `LOGIN 401` setelah ganti `JWT_SECRET` di Render — token lama jadi invalid. Solusi: login ulang.
11. 404 HTML dari Express di production — route tidak ter-register. Cek commit yang ter-deploy = commit terakhir, kalau ya → clear build cache.
12. Typo command PowerShell (misal `node server.jsnode server.js`) — cek perintah sebelum Enter.
13. `RESOURCE_EXHAUSTED: Quota exceeded` — Firestore free tier harian habis. Penyebab: rotator token tulis Firestore terlalu sering. Solusi: Fase 1 (in-memory token rotation) — token disimpan di RAM, tidak tulis Firestore lagi.
14. `SyntaxError: Unexpected token '?'` di `tokenStoreService.js` — kode `??` ketulis jadi `? ?` (ada spasi). Solusi: ganti `??` dengan if-else eksplisit.
15. Watchdog trigger saat TFT belum terpasang — firmware coba render QR ke TFT yang tidak ada, SPI blocking. Solusi: `ENABLE_TFT false` di `config.h` untuk dev mode.
16. GPIO 34-39 flapping (pintu terbuka-tutup tanpa henti) — pin input-only tidak punya internal pull-up. Solusi dev: `ENABLE_DOOR_SENSOR false`. Solusi hardware: resistor pull-up 10kΩ ke 3.3V.
17. `[Sync] HTTP 404 Cannot POST /api/firmware/esp32_01/sync` — endpoint `/sync` belum ke-commit/deploy. Solusi: commit backend, push, deploy Render.
18. **`401 INVALID_DEVICE_TOKEN` dengan token yang "sama"`** — 1 karakter hilang saat copy-paste token. Solusi: copy token dari Firestore Console (`controllers/esp32_01.authToken`), bandingkan karakter-per-karakter.
19. FCM notification test offline — kalau HP penerima tidak terhubung internet, notifikasi tertahan di FCM dan baru muncul saat HP kembali online. Ini behavior by design (FCM TTL default 4 minggu). Sudah tested dan bekerja sesuai harapan.
20. `pins_arduino.h: No such file or directory` saat build firmware — paket framework Arduino-ESP32 di PlatformIO tidak lengkap. Solusi: hapus folder `framework-arduinoespressif32` di `.platformio\packages` (folder `.platformio` tersembunyi di Windows), lalu build ulang agar diunduh lagi.
21. TFT: backlight menyala tapi layar gelap — modul ST7789 7 pin **tanpa CS** tidak merespons dengan pengaturan default. Solusi (terbukti di bench test 15 Okt 2026): **SPI mode 3** dan **RES dari GPIO 5** (bukan ke 3V3).
22. `main.cpp` tidak bisa di-compile — penanda konflik merge (`<<<<<<<`, `>>>>>>>`) tersisa. Solusi: hapus penanda dan gabungkan kedua sisi.
23. `undefined reference to setup()/loop()` di env tes (`rawtft`/`bench`) — file tes tidak ikut terkompilasi oleh `build_src_filter`. Solusi: pastikan nama file persis dan di `src/`, lalu `pio run -e <env> -t clean` dan build ulang.
24. Reminder FCM tidak muncul tiap 1 menit — `REMINDER_THROTTLE` 60 detik sama dengan interval scheduler 60 detik; jitter latency Firestore membuat selisih waktu 59,9 detik → di-skip → efektif tiap 2 menit. Solusi: `REMINDER_THROTTLE_MS = 50s`, scheduler tetap 60s.
25. Request FCM reminder diduga ditolak `INVALID_ARGUMENT` — `android.notification.setOnlyAlertOnce` bukan field FCM v1. Solusi: hapus field itu; sifat silent diatur lewat channel `smart_locker_reminder` (Low). Belum terkonfirmasi di log Render.
26. Reminder menumpuk di tray (bukan accordion) — `collapseKey` hanya menggabungkan pesan yang belum terkirim. Solusi: tambahkan `android.notification.tag = locker_{id}`.
27. Reminder tetap belum muncul setelah perbaikan #24–#26 — **masih diinvestigasi**; `fcmService.js` kini mencetak `[fcm] GAGAL (...)` dengan kode error per token. Menunggu log Render.

---

## 8. Status Saat Ini

### Backend:

- ☑ Setup hosting backend (Render.com) + Firestore
- ☑ Batch 1: 4 endpoint pelanggan
- ☑ Batch 2: 2 endpoint firmware + service latar
- ☑ Batch 3: 4 endpoint admin (login JWT, list, resolve, register-device)
- ☑ Batch 4: rate limiter + FCM
- ☑ Batch 5: reports endpoint
- ☑ Fase 1: in-memory token rotation (fix quota)
- ☑ Fase 4: device auth token
- ☑ Fase 5: endpoint `/sync`
- ☑ Fase 6: anti alarm fatigue (FCM polish)
- ◐ Fase 7: reminder berkala, catch-up, unregister-device — kode selesai; uji pertama 21 Okt: notif awal muncul, reminder 1 menit belum muncul (sedang debugging)
- ☑ Semua endpoint di-test di lokal & production
- ☑ Service account key aman (tidak ke-commit)
- ☑ `JWT_SECRET` ter-set di Render

### Firmware:

- ☑ `wifi_client` — connect + reconnect (tested)
- ☑ `backend_poller` (sync mode) — tested end-to-end
- ☑ `lock_control` — compile OK, belum test relay fisik
- ☑ `door_sensor` — compile OK, tested via jumper. **Direvisi 15 Okt:** debounce stabil, state awal dari pin, hanya `ACTIVE_LOCKERS` (belum diuji ulang)
- ☑ `event_reporter` — terintegrasi ke `/sync` (`report_door_event()` tidak dipakai di alur utama)
- ◐ `tft_render` — **15 Okt:** layar merespons di hardware asli (SPI mode 3, RES GPIO 5), teks tampil; **QR belum tampil**
- ◐ `main.cpp` — **15 Okt:** direvisi (auto-lock saat pintu tertutup / batas `UNLOCK_HOLD_MS`, `openLatch`, `forceSync`, redraw QR hanya saat token berubah, konflik merge dibersihkan); belum diuji di hardware
- ☑ `config.h` di-set untuk 2 locker (`ACTIVE_LOCKERS 2` di production mode)

### App Petugas (Reza):

- ☑ Integrasi FCM di app Flutter petugas (Reza) — selesai & tested
- ☑ Login sebagai `petugas3` di app Flutter
- ☑ Notifikasi diterima saat app terbuka
- ☑ Notifikasi diterima saat app tertutup (via baki notifikasi)
- ☑ Notifikasi tertahan saat offline, muncul saat online
- ◐ Unregister saat logout, catch-up snackbar, 2 notification channel (Fase 7) — menunggu deploy backend & uji

### Belum:

- □ Deploy backend Fase 7 ke Render (Clear build cache & deploy)
- □ Uji end-to-end reminder + catch-up + unregister (termasuk ROM Android agresif)
- □ Debug reminder 1 menit — ambil log Render (`[reminder tick]`, `[fcm reminder]`, `[fcm] GAGAL`)
- □ Samakan TTL FCM: kode 1 jam vs desain 30 menit
- □ Test end-to-end hardware fisik (butuh relay + solenoid + sensor + TFT dari Alfian)
- □ Ganti password default `admin`/`petugas1`
- □ Merge `feature/firmware` ke `main` lewat Pull Request
- □ Debug QR di TFT (`tft_render_qr`) — belum tampil di hardware
- □ Uji limit switch di hardware (ditunda)
- □ Build & uji firmware penuh (`pio run -e esp32dev`) dengan `main.cpp` revisi
- □ Uji relay + solenoid; konfirmasi baut kunci bisa re-latch saat pintu ditutup (asumsi auto-lock)
- □ Samakan `ACTIVE_LOCKERS` di `config.h` dengan skala 2 locker (versi yang terakhir dicek: development = 1, production = 4)
- □ Putuskan solusi 2 TFT tanpa pin CS (modul ber-CS atau bus SPI terpisah)
- □ Atasi cold start Render (30–60 dtk) vs watchdog firmware (30 dtk): naikkan WDT atau cron anti-sleep

---

## 9. Keputusan Desain

| Pertanyaan                                              | Keputusan                                       |
| ------------------------------------------------------- | ----------------------------------------------- |
| Akun admin/petugas: seed manual atau endpoint register? | Seed manual di Firestore (collection `petugas`) |
| Token login                                             | JWT expire 7 hari, tanpa refresh                |
| Filter tanggal di reports                               | Tidak dulu. Tampilkan semua.                    |
| `no_hp` di reports                                      | Dimask sebagian (`0812****89`)                  |
| Firmware endpoint                                       | Device token (header `X-Device-Token`)          |
| Firmware komunikasi                                     | `POST /sync` — gabungan poll + report           |
| Token QR storage                                        | In-memory (RAM), bukan Firestore                |
| QR validity                                             | 60 detik, rotasi 5 detik, histori 15 token      |
| Skala prototype                                         | 2 locker (dari rencana awal 4)                  |

---

## 10. Langkah Selanjutnya

### 1. Hardware Integration (menunggu Alfian rakit — target 2 locker)

- Wiring relay 4-channel ke GPIO 25, 26 (2 channel aktif, 2 idle)
- Wiring sensor magnet/limit switch ke GPIO 34, 35 (2 sensor) + resistor pull-up 10kΩ
- Wiring TFT ST7789 1.3" — `SCLK=18`, `MOSI=23`, `BLK=19`
  - `Locker_01`: `CS=4`, `DC=16`
  - `Locker_02`: `CS=13`, `DC=17`
  - (`CS=14/DC=21` dan `CS=33/DC=22` idle untuk `locker_03/04`)
  - **Update 15 Okt (bench test 1 layar):** modul TFT yang dipakai 7 pin **tanpa CS** → wajib **SPI mode 3** dan **RES ke GPIO 5**. Pin CS di atas hanya berlaku untuk modul yang punya pin CS. Untuk 2 layar tanpa CS perlu keputusan (belum diuji).
- Solenoid 12V fail-secure × 2 + adaptor 12V ≥2A + diode flyback
- Detail wiring lengkap: lihat `firmware/HARDWARE_WIRING_GUIDE.md`

### 2. Integrasi FCM di App Flutter (Reza) — **DONE**

- ☑ App ambil FCM token dari Firebase Messaging
- ☑ App panggil `POST /api/admin/register-device`
- ☑ Backend simpan di `petugas_devices`
- ☑ Backend auto-kirim push saat locker jadi `needs_attention`
- ☑ Tested: notif sampai saat app terbuka & tertutup
- ◐ App panggil `POST /api/admin/unregister-device` saat logout (Fase 7) — menunggu deploy & uji

### 3. Production Hardening

- □ Ganti password default `admin/admin123` dan `petugas1/petugas123`
- □ Set `ENABLE_TFT true` dan `ENABLE_DOOR_SENSOR true` di firmware production
- □ Set `BUILD_MODE_PRODUCTION` di firmware
- □ Audit `JWT_SECRET` (harus random)

### 4. Anti Alarm Fatigue — Sudah Diimplementasi

Collapse key per `locker_id`, TTL (target 30 menit, kode saat ini 1 jam), dan prioritas high sudah jalan (Fase 6). Cooldown 10 menit sudah diganti reminder berkala 60 detik yang silent (Fase 7). Detail ada di `docs/DESAIN_NOTIFIKASI.md`.

---

## 11. Catatan untuk Sesi Berikutnya

- `reset.js` dan `seedController.js` di-gitignore — kalau clone repo di komputer baru, bikin sendiri atau pakai seed script.
- `serviceAccountKey.json` tidak ada di GitHub — generate ulang dari Firebase Console.
- Auto-deploy Render belum aktif — pakai manual deploy.
- Token QR di production seed berlaku 1 jam — untuk testing, bukan spec final (spec: 60 detik).
- `docs/API.md` adalah kontrak resmi — setiap perubahan endpoint, update dokumen dulu.
- Firmware dan backend harus sinkron — kalau ganti endpoint firmware, update `config.h` juga.
- Skala prototype = 2 locker — semua dokumentasi dan kode harus konsisten dengan angka ini.
- Env PlatformIO: `esp32dev` (firmware penuh), `bench` (tes TFT dengan library), `rawtft` (tes TFT mentah, SPI mode 3). Detail di `firmware/smart_locker_firmware_documentation.md`.
- Deploy Fase 7 (route `/unregister-device` + service reminder/catch-up) wajib **Clear build cache & deploy** di Render — kalau tidak, route baru balas 404 HTML.
- App Flutter butuh `flutter clean && flutter pub get && flutter run` setelah Fase 7 (tambah `flutter_local_notifications`).
- Pengujian hardware berjalan bertahap: TFT dulu (mentah → library → QR), baru limit switch, lalu relay/solenoid.

---

## 12. Referensi Penting

- **Repo:** [https://github.com/UUser404/Smart-locker](https://github.com/UUser404/Smart-locker)
- **Branch:** `feature/firmware`
- **Production URL:** [https://smart-locker-backend-a2ck.onrender.com](https://smart-locker-backend-a2ck.onrender.com)
- **Dashboard Render:** [https://dashboard.render.com](https://dashboard.render.com)
- **Firebase Console:** [https://console.firebase.google.com/project/smart-locker-project-45bac](https://console.firebase.google.com/project/smart-locker-project-45bac)
- **Kontrak API:** `docs/API.md`
- **SKPL:** `docs/SKPL Smart Locker IoT-final.docx`
- **Firmware docs:** `firmware/smart_locker_firmware_documentation.md`
- **Wiring guide:** `firmware/HARDWARE_WIRING_GUIDE.md`

---

## Rekap Perubahan dari Versi Sebelumnya

| Section            | Yang diubah                                                                                   |
| ------------------ | --------------------------------------------------------------------------------------------- |
| 1. Ringkasan       | Tambah skala 2 locker + referensi wiring guide                                                |
| 3. Fase 1          | 4 locker → referensi generik (karena rotator untuk semua locker)                              |
| 5. Setup           | `seed.js`: 4 → 2 locker. `Initialized 4 lockers` → `2 lockers`                                |
| 7. Troubleshooting | Tambah item #19: FCM offline retensi (behavior by design)                                     |
| 8. Status          | **FCM ditandai [x] selesai** (kamu sudah konfirmasi). Tambah poin firmware `ACTIVE_LOCKERS 2` |
| 9. Keputusan       | Tambah baris "Skala prototype: 2 locker"                                                      |
| 10. Hardware       | Wiring 2 locker detail (CS/DC spesifik per locker) + referensi wiring guide                   |
| 10. FCM            | Section diubah jadi "DONE" dengan checklist centang                                           |
| 10. Optional       | Tambah improvement anti-alarm-fatigue sebagai opsional                                        |
| 11. Catatan        | Tambah poin "Skala prototype = 2 locker"                                                      |

---

## Rekap Perubahan — Update 15 Okt 2026

| Section            | Yang diubah                                                                                                        |
| ------------------ | ------------------------------------------------------------------------------------------------------------------ |
| 5. Device Token    | Token asli diganti `<DEVICE_TOKEN>` + catatan jangan menulis token di dokumen                                      |
| 7. Troubleshooting | Tambah #20–23: `pins_arduino.h`, TFT backlight nyala layar gelap, konflik merge, `setup()` hilang                  |
| 8. Status Firmware | `door_sensor` direvisi; `tft_render` dan `main.cpp` ditandai sebagian/belum diuji                                  |
| 8. Belum           | Tambah debug QR TFT, uji limit switch, build penuh, uji relay, `ACTIVE_LOCKERS`, 2 TFT tanpa CS, WDT vs cold start |
| 10. Hardware       | Catatan modul TFT tanpa CS (SPI mode 3, RES GPIO 5)                                                                |
| 11. Catatan        | Env PlatformIO + urutan uji hardware                                                                               |

---

## Rekap Perubahan — Update 21 Okt 2026

| Section            | Yang diubah                                                                                                   |
| ------------------ | ------------------------------------------------------------------------------------------------------------- |
| 1. Ringkasan       | Tambah referensi `docs/DESAIN_NOTIFIKASI.md`                                                                  |
| 3. Batch 3 / 4     | Tambah `unregister-device`; catatan catch-up di `register-device`; `fcmService` kini 3 jenis kiriman          |
| 3. Fase 6          | Dipindah ke bawah Fase 5 (sebelumnya terselip di tengah Fase 5); cooldown 10 menit ditandai digantikan Fase 7 |
| 3. Fase 7 (baru)   | Reminder berkala 60 detik, catch-up saat login, unregister saat logout                                        |
| 4. Struktur        | `scheduler.js` + `fcmService.js` diperbarui; tambah detail fungsi `fcmService`                                |
| 8. Status          | Fase 6 ☑, Fase 7 ◐; tambah item deploy & uji di "Belum"                                                       |
| 10. FCM / Optional | Tambah unregister; "Optional Improvement" diganti catatan sudah diimplementasi                                |
| 11. Catatan        | Wajib Clear build cache untuk deploy Fase 7; `flutter clean` untuk app                                        |

## Rekap Perubahan — Update 21 Okt 2026 (lanjutan, setelah uji pertama)

| Section            | Yang diubah                                                                                                             |
| ------------------ | ----------------------------------------------------------------------------------------------------------------------- |
| 3. Fase 6          | Cooldown reset diganti penjelasan `resetCooldown()` (masih dipakai); catatan TTL kode 1 jam vs target 30 menit          |
| 3. Fase 7          | Throttle 50 detik; accordion pakai `tag`; mode `catchup`; prioritas reminder normal; log diagnostik; temuan uji pertama |
| 7. Troubleshooting | Tambah #24–#27 (throttle, `setOnlyAlertOnce`, `tag`, reminder masih diinvestigasi)                                      |
| 8. Status          | Fase 7 ◐ (reminder belum muncul); tambah item debug reminder + samakan TTL                                              |
