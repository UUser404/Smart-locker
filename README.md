# Smart Locker IoT

Sistem penyewaan locker otomatis berbasis IoT dengan **2 sisi berbeda**: sisi **pelanggan** sepenuhnya berbasis web (tanpa akun, tanpa install apa pun), dan sisi **internal Petugas Keamanan & Kebersihan** berupa app Android (Flutter) untuk memantau & menangani locker di lapangan.

**Alur pelanggan (web, via scan barcode):**

1. User melihat locker kosong → **scan barcode fisik** pakai kamera HP bawaan (bukan app khusus).
2. Barcode membuka halaman web (bisa diakses lewat internet/data seluler) yang menampilkan form singkat: **nama & nomor HP** (tanpa akun permanen).
3. Setelah submit, sistem memberi **kode unik 1x lihat** (dengan tombol copy) yang wajib disimpan sendiri oleh user, lalu locker langsung terbuka dan sesi sewa dimulai.
4. Model sesinya seperti **parkir**: tidak ada durasi ditentukan di awal, timer mulai jalan begitu locker dibuka, dan total durasi baru dihitung saat sesi diakhiri.
5. Locker otomatis terkunci lagi lewat **sensor magnet** yang mendeteksi pintu tertutup (solenoid fail-secure).
6. Untuk ambil barang: user **scan ulang barcode yang sama** → masukkan kode unik → pilih **"Buka & Lanjut Sewa"** atau **"Ambil Barang & Akhiri Sewa"**.

**Alur Petugas Keamanan & Kebersihan (app Flutter):**

7. Petugas memantau status semua locker lewat dashboard di app.
8. Kalau ada locker berstatus **"perlu perhatian"** (pintu tidak tertutup > 2 menit), app mengirim **notifikasi push** ke HP petugas.
9. Petugas turun ke lapangan, cek fisik locker, lalu tekan tombol **resolve** di app setelah beres.

Dibangun sebagai project pembelajaran IoT (kontrol solenoid, koordinasi backend-firmware-web-app), dengan skala prototipe awal **4 unit locker** di lingkungan kampus.

---

## Struktur Repo

```
.
├── firmware/     # Kode ESP32 - kontrol solenoid, baca sensor magnet, polling perintah dari backend
├── backend/      # Server API - sesi sewa, kode unik, validasi, status locker, push notification
├── web/          # Halaman web publik pelanggan (form sewa, input kode unik)
├── app/          # App Android (Flutter) - dashboard, resolve, & notifikasi untuk Petugas Keamanan & Kebersihan
└── docs/         # Dokumentasi konsep, kontrak API, hasil elisitasi
    ├── API.md
    ├── DEVELOPMENT_GUIDE.md
    └── elisitasi/
```

---

## Tim & Pembagian Tugas

Ringkasan cepat:

| Nama   | Scope                  | Folder yang Dipegang    |
| ------ | ---------------------- | ----------------------- |
| Alfian | Hardware & Elektronika | `hardware/`             |
| Galuh  | Backend & Firmware     | `firmware/`, `backend/` |
| Reza   | Web & App Petugas      | `web/`, `app/`          |

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

**Firmware (`firmware/src/`):**

- [ ] `wifi_client` — koneksi ESP32 ke WiFi kampus (STA mode)
- [ ] `backend_poller` — polling ke backend tiap 2 detik, eksekusi perintah unlock
- [ ] `lock_control` — kontrol relay/solenoid per locker (index 0-3)
- [ ] `door_sensor` — baca sensor magnet + debounce, deteksi opened/closed
- [ ] `event_reporter` — kirim laporan perubahan status pintu ke backend

**Backend (`backend/src/`):**

- [ ] Routes: `lockers` (status/rent/access), `rentals` (status sesi), `firmware` (poll/report), `admin` (dashboard/resolve/register-device)
- [ ] Service `unique_code` — generate kode unik + hashing
- [ ] Service `command_queue` — antrian perintah unlock per locker
- [ ] Service `timeout_monitor` — job cek locker "terbuka > 2 menit"
- [ ] Service `rate_limiter` — batasi percobaan kode salah
- [ ] Integrasi push notification (FCM) ke app petugas
- [ ] Setup database (skema rental, locker) & hosting yang bisa diakses internet
- [ ] Menjaga `docs/API.md` tetap update setiap ada perubahan endpoint

### Reza — Web & App Petugas

**Web pelanggan (`web/public/`):**

- [ ] `scan.html` — halaman hasil scan, render beda tergantung status locker (kosong/terisi/perlu perhatian)
- [ ] Form sewa (nama & no HP) + tampilan kode unik (dengan tombol copy)
- [ ] Halaman input kode unik + pilihan "Lanjut Sewa" / "Akhiri Sewa"
- [ ] `script.js` — fetch status locker, submit form, polling durasi berjalan tiap 3 detik

**App Flutter petugas (`app/lib/`):**

- [ ] Dashboard status semua locker (kosong/disewa/perlu perhatian)
- [ ] Tombol resolve untuk locker `needs_attention`
- [ ] Setup push notification (FCM client-side) + pendaftaran token ke backend
- [ ] Tampilan detail locker bermasalah (sejak kapan terbuka, dsb)

---

## Timeline & Jadwal Kerja

Estimasi untuk durasi project **1 semester (~14 minggu)** — bisa disesuaikan tergantung jadwal akademik & kecepatan progres tim sebenarnya.

| Minggu | Fokus Kegiatan                                                      | PIC           |
| ------ | ------------------------------------------------------------------- | ------------- |
| 1      | Riset & finalisasi konsep _(sudah selesai)_                         | Semua         |
| 2      | Pelaksanaan wawancara 4 stakeholder + JAD dengan dosen pengampu     | Semua         |
| 3      | Pengadaan komponen & alat sesuai RAB                                | Alfian        |
| 3      | Setup skeleton project backend (routes, models, database)           | Galuh         |
| 4      | Wiring dasar: 1 relay + 1 solenoid + 1 sensor magnet (bench test)   | Alfian, Galuh |
| 4      | Setup hosting backend supaya bisa diakses internet                  | Galuh         |
| 5      | Firmware: `wifi_client`, `backend_poller`, `lock_control`           | Galuh         |
| 5      | Desain awal halaman web pelanggan (wireframe/tampilan)              | Reza          |
| 6      | Firmware: `door_sensor`, `event_reporter`                           | Galuh         |
| 6      | Web: form sewa (nama & no HP) + integrasi ke endpoint `/rent`       | Reza          |
| 7      | Backend: `unique_code`, `command_queue`, `rate_limiter`             | Galuh         |
| 7      | Web: tampilan kode unik + halaman input kode unik (`/access`)       | Reza          |
| 8      | Backend: `timeout_monitor` + integrasi push notification (FCM)      | Galuh         |
| 8      | Mulai app Flutter petugas: setup project + dashboard awal           | Reza          |
| 9      | Wiring & pemasangan ke 4 unit locker sekaligus                      | Alfian        |
| 9      | App Flutter: tombol resolve + pendaftaran token FCM                 | Reza          |
| 10     | Integrasi end-to-end: scan → sewa → buka → tutup → sesi tercatat    | Semua         |
| 11     | Uji 4 locker sekaligus + race condition + notifikasi ke app petugas | Semua         |
| 12     | Rakit casing/mekanik fisik ke lemari                                | Alfian        |
| 12     | Uji skenario tepi: timeout, kode salah berkali-kali (rate limit)    | Galuh, Reza   |
| 13     | Simulasi penggunaan oleh orang awam + perbaikan bug dari temuan     | Semua         |
| 14     | Dokumentasi akhir, persiapan demo, deploy prototipe                 | Semua         |

---

Kontrak endpoint HTTP antara backend, firmware, web, dan app didokumentasikan di [`docs/API.md`](docs/API.md) — **selalu update dokumen ini kalau ada perubahan endpoint**, supaya bagian lain tidak break.

---

## Arsitektur Singkat

- **Backend server (hosting internet):** single source of truth untuk status tiap locker (kosong/disewa/perlu perhatian), sesi sewa, dan kode unik. Bisa diakses dari mana saja lewat internet.
- **Firmware (ESP32 per unit locker):** karena backend di-hosting di internet sementara ESP32 ada di jaringan lokal kampus, **ESP32 yang polling ke backend** secara berkala (bukan backend yang memanggil ESP32 langsung) untuk cek ada perintah buka atau tidak, sekaligus melaporkan status sensor magnet (pintu terbuka/tertutup).
- **Web (pelanggan, diakses lewat scan barcode):** form sewa singkat (nama & no HP), tampilan kode unik, halaman input kode unik untuk ambil barang. Tidak ada dashboard di sini — murni alur transaksi pelanggan.
- **App Flutter (internal, Petugas Keamanan & Kebersihan):** dashboard status semua locker, tombol resolve untuk locker "perlu perhatian", dan push notification real-time saat ada locker bermasalah — dipilih Flutter (bukan web) khusus di sisi ini karena butuh notifikasi push yang jauh lebih mudah diimplementasikan lewat app native.
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

Merge ke `main` lewat Pull Request, bukan push langsung.

## Tracking Progress

Gunakan tab **Issues** dan **Projects** (kanban: To Do / In Progress / Done) di repo ini untuk tracking task per orang.
