# Smart Locker IoT

Sistem penyewaan locker otomatis berbasis IoT, **sepenuhnya berbasis web** — tanpa perlu daftar akun maupun install aplikasi apa pun. Tiap locker punya **barcode/QR unik** yang langsung berisi link web:

1. User melihat locker kosong → **scan barcode fisik** pakai kamera HP bawaan (bukan app khusus).
2. Barcode membuka halaman web (bisa diakses lewat internet/data seluler) yang menampilkan form singkat: **nama & nomor HP** (tanpa akun permanen).
3. Setelah submit, sistem memberi **kode unik 1x lihat** (dengan tombol copy) yang wajib disimpan sendiri oleh user, lalu locker langsung terbuka dan sesi sewa dimulai.
4. Model sesinya seperti **parkir**: tidak ada durasi ditentukan di awal, timer mulai jalan begitu locker dibuka, dan total durasi baru dihitung saat sesi diakhiri.
5. Locker otomatis terkunci lagi lewat **sensor magnet** yang mendeteksi pintu tertutup (solenoid fail-secure).
6. Untuk ambil barang: user **scan ulang barcode yang sama** → masukkan kode unik → pilih **"Buka & Lanjut Sewa"** atau **"Ambil Barang & Akhiri Sewa"**.

Dibangun sebagai project pembelajaran IoT (kontrol solenoid, koordinasi backend-firmware-web), dengan skala prototipe awal **4 unit locker** di lingkungan kampus.

---

## Struktur Repo

```
.
├── firmware/     # Kode ESP32 - kontrol solenoid, baca sensor magnet, polling perintah dari backend
├── backend/      # Server API - sesi sewa, kode unik, validasi, status locker, dashboard petugas
├── web/          # Halaman web publik (form sewa, input kode unik) + halaman dashboard petugas
└── docs/         # Dokumentasi konsep, kontrak API, hasil elisitasi
    ├── API.md
    ├── DEVELOPMENT_GUIDE.md
    └── elisitasi/
```

---

## Tim & Pembagian Tugas

| Nama   | Scope                  | Tanggung Jawab Utama                                                         |
| ------ | ---------------------- | ---------------------------------------------------------------------------- |
| Alfian | Hardware & Elektronika | Wiring solenoid + relay + sensor magnet per locker, power supply, casing     |
| Galuh  | Backend & Firmware     | Server API (sesi sewa, kode unik, timeout), firmware ESP32 (polling + relay) |
| Reza   | Web Frontend           | Halaman scan/form sewa, input kode unik, dashboard status untuk petugas      |

Kontrak endpoint HTTP antara backend, firmware, dan web didokumentasikan di [`docs/API.md`](docs/API.md) — **selalu update dokumen ini kalau ada perubahan endpoint**, supaya bagian lain tidak break.

---

## Arsitektur Singkat

- **Backend server (hosting internet):** single source of truth untuk status tiap locker (kosong/disewa/perlu perhatian), sesi sewa, dan kode unik. Bisa diakses dari mana saja lewat internet.
- **Firmware (ESP32 per unit locker):** karena backend di-hosting di internet sementara ESP32 ada di jaringan lokal kampus, **ESP32 yang polling ke backend** secara berkala (bukan backend yang memanggil ESP32 langsung) untuk cek ada perintah buka atau tidak, sekaligus melaporkan status sensor magnet (pintu terbuka/tertutup).
- **Web (diakses lewat scan barcode):** form sewa singkat (nama & no HP), tampilan kode unik, halaman input kode unik untuk ambil barang, dan dashboard status locker untuk petugas keamanan/kebersihan.
- **Tanpa akun permanen:** identitas user cuma nama + no HP per sesi, diverifikasi lewat kode unik yang di-generate sekali per sesi sewa.
- **Auto-lock:** sensor magnet (reed switch) mendeteksi pintu tertutup → itu yang memicu backend menandai locker terkunci kembali (atau menyelesaikan sesi, tergantung pilihan user saat itu).
- **Mitigasi pintu tidak tertutup:** kalau setelah dibuka pintu tidak terdeteksi tertutup dalam 2 menit, locker otomatis ditandai **"perlu perhatian"** dan tidak bisa disewa sampai dicek manual oleh petugas lewat dashboard.

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
