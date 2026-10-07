Dokumentasi Progress — Smart Locker: Backend & Hosting
Dokumen ini merangkum apa yang sudah dikerjakan untuk sisi backend
server (Express + Firestore) dan hosting (Render.com) dari project
Smart Locker IoT, dari awal sampai sesi kerja terakhir. Simpan sebagai
catatan lanjutan untuk sesi berikutnya.

1. Ringkasan Proyek
   Smart Locker adalah sistem penyewaan locker otomatis berbasis QR
   dinamis dan web (tanpa akun permanen), dengan sisi internal berupa app
   Flutter untuk Petugas Keamanan & Kebersihan.

Backend server berperan sebagai single source of truth untuk:

Status tiap locker (empty / occupied / needs_attention)

Sesi sewa (start, durasi, akhir)

Kode unik sewa (disimpan ter-hash SHA-256)

Token QR dinamis per locker (dirotasi saat locker kosong, dibekukan saat occupied)

Antrian perintah unlock untuk firmware ESP32

Push notification (FCM) ke app petugas

Rate limiting percobaan kode salah

Autentikasi petugas/admin pakai JWT

Peran user di project ini: membangun backend server + firmware ESP32.

Dokumen sumber lengkap (sudah ada sebelumnya, tidak diulang di sini):

docs/API.md — kontrak resmi endpoint

docs/DEVELOPMENT_GUIDE.md — konsep, 5W1H, arsitektur, RAB

docs/SKPL_Smart_Locker_IoT_final.docx — SKPL resmi

DOKUMENTASI_PROGRESS.md — progress app Flutter petugas (sisi Reza)

2. Keputusan Arsitektur
   Aspek Keputusan Alasan
   Framework Express.js (Node.js) Ringan, banyak referensi, tidak butuh build step
   Database Firestore (Firebase) Free tier cukup, realtime, tidak perlu setup server DB
   Hosting Render.com (free tier) Tanpa kartu kredit untuk awal, auto-deploy dari GitHub
   Credential Service Account Key via env variable Karena backend jalan di luar infrastruktur Google
   Autentikasi pelanggan Tidak ada Sesuai konsep: tanpa akun permanen
   Autentikasi admin/petugas JWT 7 hari, tanpa refresh Cukup untuk prototipe kampus, simpel untuk app
   Password storage bcrypt (cost 10) Praktik baik untuk hashing password
   Kode unik sewa SHA-256 hash Kode asli hanya ditampilkan 1x, tidak bisa diambil ulang
   Rate limiter Firestore-based (bukan in-memory) Konsisten di multi-instance, persist antar-restart
   Kenapa tidak pakai Firebase Cloud Functions?

Rencana awal backend di-deploy sebagai Firebase Cloud Functions. Tapi
firebase deploy --only functions gagal karena butuh paket Blaze
(pay-as-you-go) untuk mengaktifkan API Cloud Build. Solusi: pindah ke
Express server biasa yang di-hosting di Render, tetap akses Firestore
yang sama lewat service account key.

3. Endpoint yang Sudah Selesai
   Semua endpoint di bawah ini sudah live di production dan sudah ditest.

Batch 1 — Endpoint Pelanggan (Web)
Endpoint Method Fungsi Status
/api/lockers/:id/status GET Cek status locker (validasi token QR) ✅
/api/lockers/:id/rent POST Sewa locker baru (generate kode unik, antri unlock) ✅
/api/lockers/:id/access POST Buka ulang / akhiri sewa (validasi kode unik) ✅
/api/rentals/:id/status GET Cek status sesi & durasi berjalan ✅
Batch 2 — Endpoint Firmware + Service Latar
Endpoint Method Fungsi Status
/api/firmware/:controllerId/poll GET ESP32 ambil perintah unlock + token QR ✅
/api/firmware/:controllerId/report POST ESP32 lapor event opened/closed ✅
Service latar:

qrTokenRotatorService — rotasi token QR tiap 5 detik, simpan histori 15 token terakhir

timeoutMonitorService — deteksi pintu tidak tertutup > 2 menit → needs_attention

commandQueueService — antrean perintah unlock (consume-once)

Batch 3 — Endpoint Admin (App Petugas)
Endpoint Method Fungsi Auth Status
/api/auth/login POST Login petugas/admin - ✅
/api/admin/lockers GET List semua locker + status Bearer JWT ✅
/api/admin/lockers/:id/resolve POST Resolve locker needs_attention → empty Bearer JWT ✅
/api/admin/register-device POST Daftarkan FCM token petugas - ✅
Batch 4 — Rate Limiter + FCM
Tidak ada endpoint baru, tapi service baru:

rateLimiterService — batasi 5 percobaan kode salah per locker per 10 menit, lock 5 menit

fcmService — kirim push notification ke semua device petugas saat locker jadi needs_attention

Rate limiter di-integrasikan ke endpoint /api/lockers/:id/access.

Batch 5 — Reports Endpoint
Endpoint Method Fungsi Auth Status
/api/admin/reports/rentals GET Laporan sesi sewa + statistik (role admin) Bearer JWT ✅
Response field: stats (total_rentals, avg_duration_seconds, busiest_locker_id) dan rentals (dengan no_hp di-mask sebagian).

Catatan penting: sesi yang diakhiri via /access (action=end) masih
berstatus pending_end, belum completed. Finalisasi sesi baru
terjadi saat firmware kirim event closed lewat /api/firmware/.../report
(Batch 2). Ini sesuai kontrak docs/API.md bagian 6.

4. Struktur Kode
   text
   backend-express/
   ├── server.js # entry point (Express + startScheduler)
   ├── seed.js # seed 4 locker untuk testing
   ├── seedPetugas.js # seed akun admin & petugas1
   ├── reset.js # reset state locker + rate_limits (dev only)
   ├── package.json
   ├── .gitignore # node_modules, serviceAccountKey.json, .env, reset.js
   ├── serviceAccountKey.json # rahasia, tidak di-commit
   └── src/
   ├── firebase.js # init Firestore (dipakai semua file)
   ├── scheduler.js # cron rotasi token + timeout monitor
   ├── middleware/
   │ └── authMiddleware.js # requireAuth, requireRole
   ├── routes/
   │ ├── auth.js # POST /login
   │ ├── admin.js # endpoint admin (lockers, resolve, register-device)
   │ ├── lockers.js # endpoint pelanggan (status, rent, access)
   │ ├── rentals.js # endpoint sesi (rental status)
   │ └── firmware.js # endpoint firmware (poll, report)
   └── services/
   ├── uniqueCodeService.js # generate + hash + verify kode unik
   ├── qrTokenService.js # generate + rotasi + validasi token QR
   ├── qrTokenRotatorService.js # job rotasi token
   ├── commandQueueService.js # antrean perintah unlock
   ├── timeoutMonitorService.js # job deteksi pintu tidak tertutup
   ├── authService.js # hash/verify password + JWT
   ├── rateLimiterService.js # batasi percobaan kode salah
   └── fcmService.js # kirim push notification
   Detail tiap file penting
   src/firebase.js
   Inisialisasi Firebase Admin SDK. Support 3 mode sumber credential:

Env var FIREBASE_SERVICE_ACCOUNT_BASE64 (untuk production di Render)

Env var FIREBASE_SERVICE_ACCOUNT (alternatif JSON string)

File serviceAccountKey.json (untuk lokal)

Pakai API modular (initializeApp, cert, getFirestore) — bukan
admin.credential — karena firebase-admin v14 sudah pindah ke
modular.

src/services/uniqueCodeService.js

Generate kode unik 8 karakter dari charset ABCDEFGHJKLMNPQRSTUVWXYZ23456789 (tanpa 0/O/1/I biar gampang dibaca user)

Hash pakai SHA-256 sebelum simpan ke Firestore

verifyCode(inputCode, storedHash) untuk validasi

src/services/qrTokenService.js

Generate token QR: 6 karakter hex

isTokenValid(qrTokens, token) — cek token ada di histori & belum expired (60 detik)

rotateTokens(qrTokens) — tambah token baru, buang yang expired, batasi histori 15 token

src/services/qrTokenRotatorService.js
Job yang jalan tiap 5 detik. Cari locker empty yang belum frozen,
rotasi token-nya. Locker occupied di-skip karena token dibekukan.

src/services/timeoutMonitorService.js
Job yang jalan tiap 30 detik. Cari locker occupied yang
unlockedSince-nya > 2 menit, ubah ke needs_attention, kirim FCM
push ke petugas.

src/services/commandQueueService.js

consumeCommands(db, controllerId) — ambil pendingCommand: "unlock" dari semua locker controller ini, clear field-nya, return array commands

collectQrTokens(db, controllerId) — kumpulkan token terbaru tiap locker untuk response poll

src/services/authService.js

hashPassword / verifyPassword — pakai bcryptjs

generateToken / verifyToken — pakai jsonwebtoken, expire 7 hari

src/middleware/authMiddleware.js

requireAuth — cek header Authorization: Bearer <token>

requireRole(...roles) — cek req.user.role cocok

src/services/rateLimiterService.js

checkLock(lockerId) — cek apakah locker sedang terkunci

recordFailedAttempt(lockerId) — catat percobaan salah dalam window 10 menit, lock 5 menit kalau >= 5

resetAttempts(lockerId) — clear counter kalau kode benar

src/services/fcmService.js

notifyNeedsAttention(lockerId) — kirim FCM push ke semua token di collection petugas_devices

src/scheduler.js

setInterval rotasi token tiap 5 detik

setInterval timeout monitor tiap 30 detik

5. Setup Lokal
   Prasyarat
   Node.js v20 atau lebih baru

Akses ke Firebase Console project smart-locker-project-45bac

Git

Langkah
Masuk folder backend-express:

powershell
cd backend-express
Install dependency:

powershell
npm install
Ambil service account key dari Firebase Console:

Firebase Console → ⚙️ Project Settings → Service accounts → Generate new private key

Simpan sebagai backend-express/serviceAccountKey.json

Seed data:

powershell
node seed.js
node seedPetugas.js
Output seed.js: 4 token locker (berlaku 1 jam untuk testing).
Output seedPetugas.js: akun admin/admin123 dan petugas1/petugas123.

Jalankan server:

powershell
node server.js
Harus muncul: Server jalan di port 3000 dan [scheduler] started

Test endpoint pakai Thunder Client / Postman / curl.

Akun Testing
Username Password Role
admin admin123 admin
petugas1 petugas123 petugas
⚠️ Ganti password ini di production sebelum demo.

6. Deploy ke Render (Production)
   Base URL production: https://smart-locker-backend-a2ck.onrender.com

Konfigurasi Web Service di Render
Field Nilai
Repository User404/Smart-locker
Branch feature/firmware
Root Directory backend-express
Runtime Node
Build Command npm install
Start Command npm start
Instance Type Free
Region Singapore
Environment Variables FIREBASE_SERVICE_ACCOUNT = isi JSON service account
NODE_VERSION = 20
JWT_SECRET = string random 48 karakter
Cara Deploy
Karena GitHub App Render belum ter-install di akun teman (repo owner
User404), auto-deploy belum aktif. Setiap update kode, harus:

Push ke GitHub seperti biasa

Buka dashboard Render → service smart-locker-backend

Klik Manual Deploy → Clear build cache & deploy (kalau ada file baru) atau Deploy latest commit (kalau cuma edit)

Tunggu 2–3 menit sampai status Live

Kapan pakai "Clear build cache"?
Wajib kalau: menambah file baru, ubah package.json, tambah route baru

Tidak perlu kalau: cuma edit isi file yang sudah ada (kecil)

Kalau lupa clear cache saat ada file baru, route baru tidak akan muncul (balas 404 HTML dari Express, bukan JSON). Ini sudah pernah kejadian di Batch 3.

7. Log Setup & Troubleshooting
   Histori masalah & solusinya:

firebase deploy --only functions gagal "must be on Blaze plan" — Cloud Functions butuh API Cloud Build yang cuma bisa diaktifkan di paket Blaze. Solusi: pindah ke Express server biasa + Render.

TypeError: Cannot read properties of undefined (reading 'cert') — firebase-admin v14 pakai API modular. Solusi: const { initializeApp, cert } = require("firebase-admin/app").

Cannot find module '@google-cloud/firestore' di Render — sub-dependency tidak ke-install otomatis. Solusi: npm install @google-cloud/firestore untuk eksplisit ke package.json.

Render build cache stale — commit baru tidak ke-deploy meski push sukses. Solusi: Clear build cache & deploy.

Server lokal masih pakai route lama — Node.js tidak auto-reload. Setelah edit, stop server (Ctrl+C) dan start ulang.

RPC failed; curl 35 Recv failure saat git push — masalah HTTP/2. Solusi: git config --global http.version HTTP/1.1.

Token QR expire saat test production — token cuma valid 60 detik. Untuk testing, reset.js kasih token berlaku 1 jam.

ReferenceError: checkLock is not defined — require rate limiter belum ada atau salah posisi. Solusi: pastikan require di baris atas lockers.js, bukan di tengah file.

LOCKER_NOT_OCCUPIED saat test rate limiter — timeout monitor sudah ubah locker ke needs_attention karena > 2 menit tanpa event closed. Solusi: ubah TIMEOUT_MS di timeoutMonitorService.js jadi 10 menit sementara untuk testing.

LOGIN 401 setelah ganti JWT_SECRET di Render — token lama jadi invalid. Solusi: login ulang untuk dapat token baru.

404 HTML dari Express di production — route tidak ter-register. Cek: apakah commit yang ter-deploy = commit terakhir? Kalau ya, clear build cache. Kalau masih, cek server.js di GitHub apakah mount route-nya benar.

Typo command di PowerShell (misal node server.jsnode server.js) — sering karena copy-paste ganda. Cek dulu perintah sebelum Enter.

8. Status Saat Ini
   ☑ Setup hosting backend (Render.com) + Firestore dari production
   ☑ Batch 1: 4 endpoint pelanggan
   ☑ Batch 2: 2 endpoint firmware + service latar (rotator, timeout, command queue)
   ☑ Batch 3: 4 endpoint admin (login JWT, list, resolve, register-device)
   ☑ Batch 4: rate limiter + FCM push notification
   ☑ Batch 5: reports endpoint (GET /api/admin/reports/rentals)
   ☑ Semua endpoint di-test di lokal & production
   ☑ Service account key aman (tidak ke-commit)
   ☑ JWT_SECRET ter-set di Render
   ☑ Akun default (admin, petugas1) ter-seed di Firestore
   □ Firmware ESP32 (wifi client, backend poller, lock control, door sensor, event reporter)
   □ Integrasi FCM di app Flutter petugas (Reza)
   □ Ganti password default admin/petugas1 (production hardening)
   □ Merge feature/firmware ke main lewat Pull Request
9. Keputusan Desain (dari PROPOSAL_API_ADDITION.md)
   Pertanyaan Keputusan
   Akun admin/petugas: seed manual atau endpoint register? Seed manual di Firestore (collection petugas)
   Token login: static, JWT dengan expiry, atau JWT tanpa refresh? JWT expire 7 hari, tanpa refresh
   Filter tanggal di /admin/reports/rentals? Tidak dulu. Tampilkan semua.
   no_hp di reports: ditampilkan penuh atau dimask? Dimask sebagian (0812\*\*\*\*89)
10. Langkah Selanjutnya (Belum Dikerjakan)
    Firmware ESP32
    wifi_client — koneksi ke WiFi kampus

backend_poller — polling /api/firmware/esp32_01/poll tiap 2 detik

lock_control — kontrol relay + solenoid (fail-safe)

door_sensor — baca reed switch + debounce

event_reporter — POST /api/firmware/esp32_01/report saat pintu berubah

Integrasi FCM di App Flutter (Reza)
Setelah Reza implementasi FCM di app:

App ambil FCM token dari Firebase Messaging

App panggil POST /api/admin/register-device dengan token itu

Backend simpan di petugas_devices

Selanjutnya backend auto-kirim push saat locker jadi needs_attention

Production Hardening
Ganti password default admin/admin123 dan petugas1/petugas123

Pertimbangkan rate limiter per IP untuk endpoint publik

Audit JWT_SECRET (harus random, jangan fallback)

11. Catatan untuk Sesi Berikutnya
    reset.js di-gitignore — kalau clone repo di komputer baru, bikin reset.js sendiri (lihat commit history) atau pakai seed.js

serviceAccountKey.json tidak ada di GitHub — generate ulang dari Firebase Console

Auto-deploy Render belum aktif — pakai manual deploy

Token QR di production seed berlaku 1 jam — untuk testing, bukan spec final (spec: 60 detik)

docs/API.md adalah kontrak resmi — setiap perubahan endpoint, update dokumen dulu

DOKUMENTASI_PROGRESS.md (Reza) untuk sisi app Flutter, dokumen ini untuk sisi backend

12. Referensi Penting
    Repo: https://github.com/UUser404/Smart-locker

Branch: feature/firmware

Production URL: https://smart-locker-backend-a2ck.onrender.com

Dashboard Render: https://dashboard.render.com

Firebase Console: https://console.firebase.google.com/project/smart-locker-project-45bac

Kontrak API: docs/API.md

SKPL: docs/SKPL_Smart_Locker_IoT_final.docx
