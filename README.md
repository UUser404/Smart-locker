# Smart Locker IoT

Sistem penyewaan locker otomatis berbasis IoT. Tiap locker punya **barcode/QR unik**, dan proses sewa dilakukan lewat aplikasi Android (**Flutter**):

1. User **mendaftar** ke sistem Smart Locker (registrasi akun).
2. User memesan locker → sistem membuat sesi sewa **1x pakai**. Model sesinya seperti **parkir**: tidak ada durasi ditentukan di awal, timer mulai jalan begitu locker dibuka (scan-in), dan total durasi baru dihitung saat sesi diakhiri.
3. Aplikasi menampilkan **scanner** (memakai kamera HP) → user scan barcode di salah satu locker fisik yang dipilih.
4. Kalau barcode valid & cocok dengan sesi sewa yang aktif → user diberi **akses membuka locker** tersebut, dan durasi pakainya mulai dihitung berjalan.

Dibangun sebagai project pembelajaran IoT/elektronika & pemrograman platform mobile (kontrol solenoid, koordinasi backend-firmware-app), dengan skala prototipe awal **4 unit locker**.

---

## Struktur Repo

```
.
├── firmware/     # Kode microcontroller (ESP32) - kontrol solenoid tiap locker
├── backend/      # Server API - registrasi user, sesi sewa, validasi barcode
├── app/          # App Android (Flutter) - scan barcode via kamera HP, status & durasi sewa
└── docs/         # Dokumentasi konsep, kontrak API, catatan progres
    ├── API.md
    └── DEVELOPMENT_GUIDE.md
```

---

## Tim & Pembagian Tugas

| Nama   | Scope                  | Tanggung Jawab Utama                                                         |
| ------ | ---------------------- | ---------------------------------------------------------------------------- |
| Alfian | Hardware & Elektronika | Wiring solenoid + relay per locker, power supply, casing/mekanik locker      |
| Galuh  | Backend & Firmware     | Server API (auth, sesi sewa, validasi barcode), firmware ESP32 kontrol relay |
| Reza   | App Android (Flutter)  | UI scan barcode (kamera HP), tampilan status & durasi berjalan sewa          |

Kontrak endpoint HTTP antara backend, firmware, dan app didokumentasikan di [`docs/API.md`](docs/API.md) — **selalu update dokumen ini kalau ada perubahan endpoint**, supaya bagian lain tidak break.

---

## Arsitektur Singkat

- **Backend server:** memegang _single source of truth_ untuk akun user, sesi sewa (rental), dan status tiap locker (kosong/disewa/menunggu-scan)
- **Microcontroller (ESP32):** terhubung ke WiFi yang sama dengan backend, menerima perintah "buka locker X" dan mengontrol relay → solenoid door lock
- **App Android (Flutter):** tempat user daftar, pesan locker, dan scan barcode lewat kamera HP (pakai package scanner seperti `mobile_scanner`, bukan scanner fisik terpisah)
- **Barcode:** ditempel di tiap locker, berisi ID unik locker; validasi keabsahan & kecocokan dengan sesi sewa dilakukan di backend, bukan di app maupun firmware

Detail lengkap ada di [`docs/DEVELOPMENT_GUIDE.md`](docs/DEVELOPMENT_GUIDE.md).

---

## Cara Kerja Branch

- `main` — kode stabil & sudah teruji
- `feature/firmware-*` — pengembangan firmware ESP32
- `feature/backend-*` — pengembangan server API
- `feature/app-*` — pengembangan app Flutter
- `feature/hardware-*` — dokumentasi wiring, kalibrasi, casing locker

Merge ke `main` lewat Pull Request, bukan push langsung.

## Tracking Progress

Gunakan tab **Issues** dan **Projects** (kanban: To Do / In Progress / Done) di repo ini untuk tracking task per orang.
