Rancangan Perubahan: Alur Scan QR via Kamera Bawaan HP
Berdasarkan kesepakatan tim (Galuh, Reza, Alfian) dan arahan dosen PBP, berikut adalah rancangan teknis untuk mengubah alur scan QR dari aplikasi web ke kamera bawaan HP.

1. Alur Baru (Updated User Flow)
   Scan: Pengguna mengarahkan kamera bawaan HP ke layar TFT Loker.

Redirect: HP otomatis membuka browser dan mengarah ke URL Web (misal: https://www.locker-qu.com/locker/01?token=abc123).

Form (Koreksi Reza): Web mengekstrak token dan locker_id dari URL, lalu menampilkan Form Nama & No HP.

Sewa: Setelah user submit form, Web memanggil API POST /api/lockers/:id/rent ke Backend dengan payload { nama, no_hp, token }.

2. Perubahan di Sisi Backend (backend-express)
   Kita tidak perlu mengubah logika rotasi token. Kita hanya perlu merakit URL utuh sebelum dikirim ke ESP32.

Konfigurasi .env:
Tambahkan variabel base URL web (sementara pakai placeholder sesuai instruksi Reza):

env
WEB_BASE_URL="https://www.locker-qu.com/locker"
Update src/routes/firmware.js:
Saat merespons endpoint /sync, jangan kirim token mentah (6 karakter). Ubah menjadi URL utuh yang sudah digabung dengan WEB_BASE_URL.
(Galuh akan mengerjakan bagian ini).

3. Perubahan di Sisi Firmware (firmware/smart-locker)
   Karena URL sekarang jauh lebih panjang (contoh: https://www.locker-qu.com/locker/01?token=abc123 = 53 karakter), sedangkan settingan QR_VERSION kita sekarang cuma muat ~30 karakter, kita harus meng-upgrade kapasitas QR.

Update src/config.h:
Naikkan versi QR dari 3 ke 5 atau 6.

cpp
#define QR_VERSION 5 // Atau 6, disesuaikan dengan panjang URL final
Update src/main.cpp:
Saat memanggil tft_render_qr, hapus penggabungan lockerId + token manual. Cukup passing URL utuh yang didapat dari response API backend.
(Galuh akan mengerjakan bagian ini).

4. Perubahan di Sisi Web (mprojectapp/web)
   Hapus Library Scanner: Library seperti mobile_scanner atau html5-qrcode tidak dipakai lagi di halaman utama.

Baca URL Parameter: Saat halaman dimuat, ambil parameter token dan locker_id dari URL menggunakan JavaScript (URLSearchParams).

Tampilkan Form: Tampilkan form input nama & no HP.

Kirim API: Saat form disubmit, lakukan fetch ke endpoint /rent milik backend (seperti alur sebelumnya).
