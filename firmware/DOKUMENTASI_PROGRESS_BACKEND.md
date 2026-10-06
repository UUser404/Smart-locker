Oke, aku buatkan dokumentasi progress backend mengikuti format Reza. Ini lengkap, bahasa Indonesia, informal-akademis seperti dokumen Reza.

## Rekomendasi lokasi file

**Pilihan A:** `Smart-Locker/DOKUMENTASI_PROGRESS_BACKEND.md` (di root, konsisten dengan `DOKUMENTASI_PROGRESS.md` Reza)

**Pilihan B:** `Smart-Locker/backend-express/DOKUMENTASI_BACKEND.md` (dekat dengan kode backend)

**Rekomendasiku: Pilihan A.** Karena Reza taruh di root, jadi konsisten. Dan dokumen ini level project, bukan cuma backend.

Buat file baru di VS Code: **File → New File**, simpan sebagai `DOKUMENTASI_PROGRESS_BACKEND.md` di root repo `Smart-Locker`.

Isinya:

```markdown
# Dokumentasi Progress — Smart Locker: Backend & Hosting

> Dokumen ini merangkum apa yang sudah dikerjakan untuk sisi **backend
> server (Express + Firestore)** dan **hosting (Render.com)** dari project
> Smart Locker IoT, dari awal sampai sesi kerja terakhir. Simpan sebagai
> catatan lanjutan untuk sesi berikutnya.

---

## 1. Ringkasan Proyek

Smart Locker adalah sistem penyewaan locker otomatis berbasis QR
dinamis dan web (tanpa akun permanen), dengan sisi internal berupa app
Flutter untuk Petugas Keamanan & Kebersihan.

Backend server berperan sebagai **single source of truth** untuk:

- Status tiap locker (`empty` / `occupied` / `needs_attention`)
- Sesi sewa (start, durasi, akhir)
- Kode unik sewa (disimpan ter-hash)
- Token QR dinamis per locker (dirotasi saat locker kosong, dibekukan saat occupied)
- Antrian perintah `unlock` untuk firmware ESP32
- Push notification (FCM) ke app petugas (rencana Batch 4)

**Peran user di project ini:** membangun backend server + firmware ESP32.

Dokumen sumber lengkap (sudah ada sebelumnya, tidak diulang di sini):

- `docs/API.md` — kontrak resmi endpoint
- `docs/DEVELOPMENT_GUIDE.md` — konsep, 5W1H, arsitektur, RAB
- `DOKUMENTASI_PROGRESS.md` — progress app Flutter petugas (sisi Reza)

---

## 2. Keputusan Arsitektur

Beberapa keputusan teknis yang sudah diambil:

| Aspek                           | Keputusan                                | Alasan                                                 |
| ------------------------------- | ---------------------------------------- | ------------------------------------------------------ |
| Framework                       | **Express.js (Node.js)**                 | Ringan, banyak referensi, tidak butuh build step       |
| Database                        | **Firestore (Firebase)**                 | Free tier cukup, realtime, tidak perlu setup server DB |
| Hosting                         | **Render.com (free tier)**               | Tanpa kartu kredit untuk awal, auto-deploy dari GitHub |
| Credential                      | **Service Account Key** via env variable | Karena backend jalan di luar infrastruktur Google      |
| Autentikasi backend             | Tidak ada untuk endpoint pelanggan       | Sesuai konsep: tanpa akun permanen                     |
| Autentikasi admin (app petugas) | **JWT 7 hari, tanpa refresh** (Batch 3)  | Cukup untuk prototipe kampus, simpel untuk sisi app    |

**Kenapa tidak pakai Firebase Cloud Functions?**

Rencana awal backend di-deploy sebagai Firebase Cloud Functions. Tapi
`firebase deploy --only functions` gagal karena butuh paket Blaze
(pay-as-you-go) untuk mengaktifkan API Cloud Build. Solusi: pindah ke
Express server biasa yang di-hosting di Render, tetap akses Firestore
yang sama lewat service account key.

---

## 3. Endpoint yang Sudah Selesai (Batch 1)

Endpoint pelanggan sesuai `docs/API.md` bagian 1, 2, 3, 4:

| Endpoint                  | Method | Fungsi                                              | Status |
| ------------------------- | ------ | --------------------------------------------------- | ------ |
| `/api/lockers/:id/status` | GET    | Cek status locker (dengan validasi token QR)        | ✅     |
| `/api/lockers/:id/rent`   | POST   | Sewa locker baru (generate kode unik, antri unlock) | ✅     |
| `/api/lockers/:id/access` | POST   | Buka ulang / akhiri sewa (validasi kode unik)       | ✅     |
| `/api/rentals/:id/status` | GET    | Cek status sesi & durasi berjalan                   | ✅     |

**Catatan penting:** sesi yang diakhiri via `/access` (action=end) masih
berstatus `pending_end`, **belum** `completed`. Finalisasi sesi baru
terjadi saat firmware kirim event `closed` lewat `/api/firmware/.../report`
(Batch 2). Ini sesuai kontrak `docs/API.md` bagian 6.

---

## 4. Struktur Kode yang Sudah Dibuat
```

backend-express/
├── server.js # entry point (Express + startScheduler)
├── seed.js # seed 4 locker untuk testing
├── reset.js # reset state locker ke empty (dev tool, tidak di-commit)
├── package.json
├── .gitignore # node_modules, serviceAccountKey.json, .env, reset.js
├── serviceAccountKey.json # rahasia, tidak di-commit
└── src/
├── firebase.js # init Firestore (dipakai semua file)
├── routes/
│ ├── lockers.js # 3 endpoint pelanggan
│ └── rentals.js # 1 endpoint sesi
└── services/
├── uniqueCodeService.js # generate + hash + verify kode unik
└── qrTokenService.js # generate + validasi token QR

````

### Detail tiap file

**`src/firebase.js`**
Inisialisasi Firebase Admin SDK. Support 3 mode sumber credential:
- Env var `FIREBASE_SERVICE_ACCOUNT_BASE64` (untuk production di Render)
- Env var `FIREBASE_SERVICE_ACCOUNT` (alternatif JSON string)
- File `serviceAccountKey.json` (untuk lokal)

Pakai API modular (`initializeApp`, `cert`, `getFirestore`) — bukan
`admin.credential` — karena `firebase-admin` v14 sudah pindah ke
modular. Versi lama sudah deprecated.

**`src/services/uniqueCodeService.js`**
- Generate kode unik 8 karakter dari charset `ABCDEFGHJKLMNPQRSTUVWXYZ23456789` (tanpa `0/O/1/I` biar gampang dibaca user)
- Hash pakai SHA-256 sebelum simpan ke Firestore
- Fungsi `verifyCode(inputCode, storedHash)` untuk validasi kode yang dimasukkan user

**`src/services/qrTokenService.js`**
- Generate token QR: 6 karakter hex random (`crypto.randomBytes(3).toString("hex")`)
- `isTokenValid(qrTokens, token)` — cek token ada di histori & belum expired (60 detik)
- Sementara di Batch 1: token disimpan sebagai array 1 elemen, belum rotasi otomatis. Rotasi akan ditambah di Batch 2.

**`src/routes/lockers.js`**
- `GET /:id/status?token=xxx` — validasi token, balas `status: empty|occupied|needs_attention`
- `POST /:id/rent` — validasi token + status empty, generate kode unik, set locker jadi occupied, antri command unlock. Menggunakan `db.runTransaction` untuk cegah race condition.
- `POST /:id/access` — validasi kode unik, atur `pendingEnd` di locker + `accessAction` di rental. Menggunakan transaksi juga.

**`src/routes/rentals.js`**
- `GET /:id/status` — balas status sesi + `elapsed_seconds` (kalau active) atau `total_duration_seconds` (kalau completed)

**`server.js`**
Entry point. Setup CORS + JSON parser, daftarkan 3 route utama (`/api/lockers`, `/api/rentals`, dan nanti `/api/firmware`, `/api/admin`), start scheduler di background (Batch 2).

**`seed.js`** & **`reset.js`**
Dev tool. `seed.js` bikin 4 locker (`locker_01`–`locker_04`) dengan token QR valid 1 jam (bukan 60 detik) biar gampang di-test manual. `reset.js` reset semua locker ke state bersih — berguna kalau ada test yang ninggalin locker di status `occupied`.

**`reset.js` tidak di-commit** karena berisi logic yang terlalu destruktif untuk production.

---

## 5. Setup Lokal (Cara Jalanin di Laptop)

### Prasyarat

- Node.js v20 atau lebih baru
- Akses ke Firebase Console project `smart-locker-project-45bac`
- Git

### Langkah

1. Masuk folder `backend-express`:
   ```powershell
   cd backend-express
````

2. Install dependency:

   ```powershell
   npm install
   ```

3. Ambil **service account key** dari Firebase Console:
   - Firebase Console → ⚙️ Project Settings → Service accounts → Generate new private key
   - Simpan sebagai `backend-express/serviceAccountKey.json`
   - ⚠️ File ini **jangan di-commit**. Sudah masuk `.gitignore`.

4. Seed data untuk testing:

   ```powershell
   node seed.js
   ```

   Copy token `locker_01` untuk test.

5. Jalankan server:

   ```powershell
   node server.js
   ```

   Harus muncul: `Server jalan di port 3000`

6. Test endpoint pakai Thunder Client / Postman / curl:
   ```powershell
   curl.exe "http://localhost:3000/api/lockers/locker_01/status?token=<TOKEN>"
   ```

---

## 6. Deploy ke Render (Production)

Base URL production: **`https://smart-locker-backend-a2ck.onrender.com`**

### Konfigurasi Web Service di Render

| Field                 | Nilai                                                                          |
| --------------------- | ------------------------------------------------------------------------------ |
| Repository            | `User404/Smart-locker`                                                         |
| Branch                | `feature/firmware` (akan di-merge ke `main` nanti)                             |
| Root Directory        | `backend-express`                                                              |
| Runtime               | Node                                                                           |
| Build Command         | `npm install`                                                                  |
| Start Command         | `npm start`                                                                    |
| Instance Type         | Free                                                                           |
| Region                | Singapore                                                                      |
| Environment Variables | `FIREBASE_SERVICE_ACCOUNT` = isi JSON service account<br>`NODE_VERSION` = `20` |

### Cara Deploy

Karena GitHub App Render belum ter-install di akun teman (repo owner
`User404`), auto-deploy belum aktif. Setiap update kode, harus:

1. Push ke GitHub seperti biasa
2. Buka dashboard Render → service `smart-locker-backend`
3. Klik **Manual Deploy** → **Clear build cache & deploy**
4. Tunggu 2–3 menit sampai status **Live**

**Catatan:** environment variable `FIREBASE_SERVICE_ACCOUNT` isinya
adalah **seluruh isi file JSON service account key**, bukan path file.

### Free Tier Behavior

Instance akan otomatis "tidur" setelah 15 menit tanpa request. Request
pertama setelah tidur akan lambat 30–60 detik. Ini normal dan tidak
bisa dihindari di free tier. Kalau mau demo, "bangunkan" dulu dengan
buka URL `https://smart-locker-backend-a2ck.onrender.com/` di browser
beberapa menit sebelumnya.

---

## 7. Log Setup & Troubleshooting (Kronologis)

Histori masalah yang sudah ditemui & solusinya, biar tidak mengulang
riset kalau ketemu masalah serupa:

1. **`firebase deploy --only functions` gagal dengan pesan "must be on the Blaze plan"** — Cloud Functions butuh API Cloud Build yang cuma bisa diaktifkan di paket Blaze. Solusi: pindah ke Express server biasa + Render, tidak pakai Cloud Functions sama sekali.

2. **`TypeError: Cannot read properties of undefined (reading 'cert')`** saat `admin.credential.cert(...)` di `seed.js` — penyebab: `firebase-admin` v14 memakai API modular, `admin.credential` sudah tidak ada di namespace utama. Solusi: import pakai `const { initializeApp, cert } = require("firebase-admin/app")` dan `const { getFirestore } = require("firebase-admin/firestore")`.

3. **Error deploy Render: `Cannot find module '@google-cloud/firestore'`** — meskipun sudah ada di `node_modules` lokal, npm di lingkungan Render tidak install sub-dependency ini secara otomatis. Solusi: `npm install @google-cloud/firestore` untuk menambahkannya sebagai dependency eksplisit di `package.json`.

4. **Render build cache bikin commit lama tetap ke-deploy** — setelah push commit baru, Render kadang masih pakai container lama. Solusi: klik **Manual Deploy** → **Clear build cache & deploy** (bukan yang biasa).

5. **`Error: Your project ... must be on the Blaze plan`** — muncul saat mencoba aktifkan Cloud Build API. Ini batasan Google, tidak ada workaround selain upgrade atau hindari Cloud Functions.

6. **Server lokal masih pakai route lama setelah file diubah** — Node.js tidak auto-reload. Setelah edit `server.js`, harus stop server (Ctrl+C) dan start ulang (`node server.js`). Bug ini sempat bikin bingung waktu route `/api/lockers/...` masih 404 padahal file sudah benar.

7. **`error: RPC failed; curl 35 Recv failure`** saat `git push` — error network, git pakai HTTP/2 yang bermasalah di beberapa jaringan. Solusi: `git config --global http.version HTTP/1.1`, lalu push ulang.

8. **Repo GitHub pindah nama** dari `Smart-dispenser` ke `Smart-locker` — push tetap berhasil karena GitHub redirect otomatis, tapi lebih baik update remote URL: `git remote set-url origin https://github.com/UUser404/Smart-locker.git`.

9. **Firebase Console masih menampilkan data lama** setelah refactor — perlu hapus manual collection `lockers` dan `rentals` di Firestore sebelum test ulang.

10. **Token QR expire saat test production** — token cuma valid 60 detik sesuai spec, tapi di `seed.js` di-set 1 jam untuk memudahkan testing. Kalau kena `TOKEN_EXPIRED`, tinggal jalanin `node reset.js` atau `node seed.js` lagi.

---

## 8. Status Saat Ini

- [x] Setup hosting backend (Render.com) + Firestore dari production
- [x] Refactor backend sesuai `docs/API.md` — Batch 1 (4 endpoint pelanggan)
- [x] Test lokal 5 skenario — semua pass
- [x] Deploy production & test 3 endpoint utama — semua pass
- [x] Service account key aman (tidak ke-commit)
- [x] Dokumentasi setup lengkap (dokumen ini)
- [ ] **Batch 2**: endpoint firmware (`/poll`, `/report`) + service latar (rotator QR, timeout monitor)
- [ ] **Batch 3**: endpoint admin (dashboard petugas, resolve, register FCM)
- [ ] **Batch 4**: integrasi FCM push notification + rate limiter
- [ ] **Batch 5**: login admin + reports (sesuai `PROPOSAL_API_ADDITION.md`)
- [ ] Firmware ESP32: wifi client, backend poller, lock control, door sensor, event reporter
- [ ] Merge `feature/firmware` ke `main` lewat Pull Request

---

## 9. Keputusan Desain yang Perlu Dikonfirmasi ke Tim

Beberapa hal di `PROPOSAL_API_ADDITION.md` (usulan dari sisi app Flutter)
sudah diputuskan oleh pemegang backend:

| Pertanyaan                                                      | Keputusan                                                                                   |
| --------------------------------------------------------------- | ------------------------------------------------------------------------------------------- |
| Akun admin/petugas: seed manual atau endpoint register?         | **Seed manual di Firestore** (collection `petugas`). Endpoint register tidak dibuat.        |
| Token login: static, JWT dengan expiry, atau JWT tanpa refresh? | **JWT expire 7 hari, tanpa refresh token**. Cukup untuk prototipe, tidak ribet di sisi app. |
| Filter tanggal di `/admin/reports/rentals`?                     | **Tidak dulu**. Tampilkan semua riwayat. Filter ditambah nanti kalau perlu.                 |
| `no_hp` di reports: ditampilkan penuh atau dimask?              | **Dimask sebagian** (`0812****89`). Praktik baik privasi, gampang diimplementasi.           |

---

## 10. Langkah Selanjutnya (Belum Dikerjakan)

### Batch 2 — Endpoint Firmware & Service Latar

Endpoint baru:

- `GET /api/firmware/:controllerId/poll` — ESP32 tanya perintah tiap 2 detik
- `POST /api/firmware/:controllerId/report` — ESP32 lapor event `opened`/`closed`

Service baru:

- `qrTokenRotatorService` — rotasi token tiap 5 detik, simpan histori 15 token terakhir, validitas 60 detik
- `timeoutMonitorService` — cek locker `occupied` yang pintunya belum tertutup > 2 menit, ubah ke `needs_attention`
- `commandQueueService` — antrean perintah unlock per locker (consume-once, biar tidak dieksekusi 2x)

Update:

- `POST /api/lockers/:id/access` — sekarang set `pendingEnd: true` di locker saat action=end
- `POST /api/firmware/:controllerId/report` — saat event `closed` masuk, kalau locker `pendingEnd: true` → finalisasi sesi (rental completed, locker empty)
- `server.js` — start scheduler saat server jalan

### Batch 3 — Endpoint Admin (App Flutter Petugas)

- `GET /api/admin/lockers` — list semua locker + status
- `POST /api/admin/lockers/:id/resolve` — tandai `needs_attention` → `empty`
- `POST /api/admin/register-device` — daftarkan token FCM petugas

### Batch 4 — FCM & Rate Limiter

- Integrasi Firebase Cloud Messaging untuk push notification saat locker jadi `needs_attention`
- Rate limiter untuk endpoint `/access` — maksimal 5 percobaan gagal per locker dalam 10 menit

### Batch 5 — Login & Reports

- `POST /api/auth/login` — JWT login petugas/admin
- `GET /api/admin/reports/rentals` — laporan sesi sewa

### Firmware ESP32 (Setelah Batch 2)

- `wifi_client` — koneksi ke WiFi kampus
- `backend_poller` — polling `/api/firmware/esp32_01/poll` tiap 2 detik
- `lock_control` — kontrol relay + solenoid (fail-secure)
- `door_sensor` — baca reed switch + debounce
- `event_reporter` — POST `/api/firmware/esp32_01/report` saat pintu berubah

---

## 11. Catatan untuk Sesi Berikutnya

- **Jangan lupa: `reset.js` sudah di-gitignore.** Kalau ada orang lain yang clone repo, mereka harus bikin `reset.js` sendiri atau pakai `seed.js`.
- **`serviceAccountKey.json` tidak ada di GitHub.** Kalau clone repo di komputer baru, harus generate ulang dari Firebase Console.
- **Auto-deploy Render belum aktif** karena GitHub App belum di-install di akun `User404`. Sementara pakai **Manual Deploy → Clear build cache & deploy**.
- **Test production: token expire dalam 1 jam** sejak `node seed.js`. Kalau kena `TOKEN_EXPIRED`, jalanin `node reset.js` lagi dan copy token baru.
- **`docs/API.md` adalah kontrak resmi.** Setiap perubahan endpoint di kode, update `docs/API.md` DULU sebelum commit.

````

---

## Setelah file dibuat

1. **Save** di VS Code (Ctrl+S)
2. Di PowerShell, dari folder `docs`:
   ```powershell
   git add ../DOKUMENTASI_PROGRESS_BACKEND.md
   git status
````

3. Verifikasi: `new file: DOKUMENTASI_PROGRESS_BACKEND.md` di staging. Aman.
4. Commit & push:
   ```powershell
   git commit -m "Add backend progress documentation"
   git push origin feature/firmware
   ```
