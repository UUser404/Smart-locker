# Dokumentasi Konsep — Smart Locker IoT

## 1. Ringkasan Proyek

Smart Locker adalah sistem penyewaan locker otomatis, **sepenuhnya berbasis web** — tanpa akun permanen dan tanpa install aplikasi apa pun. Tiap unit locker punya **barcode/QR unik** yang berisi link web langsung ke halaman kontrol locker tersebut.

Alur inti:

1. User scan barcode di locker fisik yang masih kosong lewat kamera HP bawaan
2. Muncul halaman web (bisa diakses lewat internet) → isi **nama & nomor HP** saja, tanpa daftar akun
3. Sistem memberi **kode unik 1x lihat** (dengan tombol copy) → user simpan sendiri, locker langsung terbuka, sesi mulai
4. Model sesi seperti **parkir**: durasi dihitung dari waktu pakai, bukan ditentukan di awal
5. Locker otomatis terkunci lagi lewat **sensor magnet** yang mendeteksi pintu tertutup
6. Untuk ambil barang: scan ulang barcode yang sama → masukkan kode unik → pilih **lanjut sewa** atau **akhiri sewa**

Dibangun sebagai project pembelajaran IoT (kontrol solenoid, sensor, koordinasi backend-firmware-web), dengan skala **prototipe 4 unit locker** di lingkungan kampus.

---

## 2. Analisis 5W1H

| Aspek     | Penjelasan                                                                                                                                        |
| --------- | ------------------------------------------------------------------------------------------------------------------------------------------------- |
| **What**  | Sistem locker sewa otomatis berbasis barcode & web, tanpa akun permanen dan tanpa app                                                             |
| **Where** | Prototipe di lingkungan kampus; backend di-hosting di internet, firmware locker ada di jaringan lokal kampus                                      |
| **Who**   | Mahasiswa & staf kampus sebagai pengguna utama; juga melibatkan pengelola aset, IT, dosen, keamanan/kebersihan                                    |
| **Why**   | Proyek belajar IoT (kontrol solenoid, sensor, sistem multi-komponen: backend + firmware + web)                                                    |
| **When**  | Dipakai kapan saja selama sistem online; tiap sesi 1x pakai, lama pakainya bebas (dihitung, bukan ditentukan di awal)                             |
| **How**   | Scan barcode → isi nama & no HP → dapat kode unik → locker terbuka, timer jalan → ambil barang: scan ulang + kode unik → pilih lanjut/akhiri sewa |

---

## 3. Konsep Interaksi Pengguna

### Sewa Baru (Locker Kosong)

1. User mengarahkan kamera HP ke barcode di salah satu locker fisik yang masih kosong
2. Terbuka halaman web (browser bawaan HP, tidak perlu install apa pun)
3. Web mengecek status locker → kosong → tampilkan **form singkat**: nama & nomor HP
4. User submit → backend generate **kode unik** (alfanumerik 6-8 karakter) → ditampilkan **1 kali** di layar dengan tombol copy, disertai peringatan untuk disimpan sendiri
5. Locker terbuka (solenoid energized), waktu mulai (`started_at`) dicatat — titik ini seperti "ambil tiket parkir"
6. User menyimpan barang, menutup pintu → sensor magnet mendeteksi tertutup → solenoid otomatis terkunci lagi, sesi tetap **aktif**
7. Selama locker dipakai, halaman web (kalau dibuka lagi) bisa menampilkan durasi berjalan (naik terus, bukan countdown)

### Ambil Barang / Buka Ulang (Locker Terisi)

8. User scan ulang barcode fisik yang sama
9. Web mengecek status locker → terisi → tampilkan pesan **"Locker sudah terisi. Jika Anda penyewa locker ini, masukkan kode unik untuk membukanya"**
10. User masukkan kode unik → kalau valid, tampil 2 pilihan:
    - **"Buka & Lanjut Sewa"** — locker terbuka, sesi tetap aktif setelah pintu ditutup lagi (misal user cuma mau ambil sesuatu tapi masih perlu locker)
    - **"Ambil Barang & Akhiri Sewa"** — locker terbuka, begitu pintu ditutup lagi sesi dianggap selesai, **total durasi dihitung** dari `started_at` sampai saat itu
11. Kalau kode salah → pesan generik **"Kode tidak valid"** (sengaja tidak dibedakan dari kasus "locker ini bukan milik Anda", supaya tidak memberi petunjuk ke orang yang coba menebak)

### Race Condition (2 Device Scan Bersamaan)

12. Kalau locker masih kosong tapi 2 device kebetulan submit form sewa nyaris bersamaan, yang lebih dulu diproses backend akan berhasil; yang kedua menerima pesan **"Sedang dalam antrian, silakan coba lagi"** — beda dari pesan "locker sudah terisi", supaya user tahu ini cuma soal waktu, bukan locker benar-benar sudah dipakai orang lain

---

## 4. Konsep Alur Sistem (End-to-End)

```
[User lihat locker kosong] --> [Scan barcode fisik]
        |
        v
[Web cek status locker] --(kosong)--> [Form nama & no HP] --> [Backend: generate kode unik, catat started_at]
        |                                                              |
        v                                                              v
   (terisi)                                                  [Perintah unlock diantrikan]
        |                                                              |
        v                                                              v
[Input kode unik] <---------------------------------------- [Firmware polling ambil perintah]
        |                                                              |
        v                                                              v
[Pilih: Lanjut Sewa / Akhiri Sewa]                          [Solenoid terbuka, sensor magnet mulai dipantau]
        |                                                              |
        v                                                              v
                                                    [Pintu ditutup] --> [Firmware laporkan event "closed"]
                                                                              |
                                              +-------------------------------+-------------------------------+
                                              |                                                               |
                                     (pilihan = akhiri sewa)                                     (pilihan = lanjut sewa / sewa baru)
                                              |                                                               |
                                              v                                                               v
                                [Backend hitung total durasi,                                    [Locker kembali status
                                 sesi selesai, locker jadi kosong]                                 occupied, sesi tetap aktif]
```

**Penanganan pintu tidak tertutup:** kalau setelah perintah unlock dieksekusi, firmware tidak pernah mengirim event `"closed"` dalam **2 menit**, backend otomatis menandai locker **`needs_attention`** — locker ini diblokir dari penyewaan baru sampai petugas keamanan/kebersihan mengecek & menutupnya secara manual lewat dashboard.

---

## 5. Arsitektur Sistem

- **Backend server (hosting internet):** single source of truth untuk status locker (`empty` / `occupied` / `needs_attention`), sesi sewa, dan kode unik (disimpan dalam bentuk hash)
- **Firmware (ESP32 per unit controller, menangani hingga 4 locker):** karena backend ada di internet sementara ESP32 ada di jaringan lokal kampus, **ESP32 yang polling ke backend** (interval 2 detik) untuk ambil perintah unlock, dan melaporkan perubahan status sensor magnet — arah komunikasi ini terbalik dari desain awal project (backend memanggil ESP32 langsung), karena sekarang backend perlu bisa diakses dari internet oleh siapa saja yang scan barcode
- **Web (halaman publik + dashboard petugas):** semua interaksi user lewat browser HP hasil scan barcode — form sewa, tampilan kode unik, input kode unik untuk ambil barang; ditambah dashboard status locker untuk petugas keamanan/kebersihan
- **Solenoid door lock:** dikontrol relay dari ESP32, skema fail-secure (default terkunci, terbuka hanya saat menerima sinyal), tetap energized sampai sensor magnet mendeteksi pintu tertutup (bukan pulsa waktu tetap)
- **Sensor magnet (reed switch):** mendeteksi pintu terbuka/tertutup, jadi pemicu auto-lock sekaligus sinyal ke backend untuk menyelesaikan atau melanjutkan sesi

---

## 6. Kebutuhan Komponen (Draft Awal)

| Komponen                    | Spesifikasi                                | Fungsi                                         |
| --------------------------- | ------------------------------------------ | ---------------------------------------------- |
| Microcontroller (ESP32)     | 1 unit (kontrol 4 relay + 4 sensor magnet) | Polling backend, kontrol solenoid, baca sensor |
| Relay module                | 4 channel, aktif LOW                       | Switch tiap solenoid                           |
| Solenoid door lock          | 12V, fail-secure, 4 unit                   | Mekanisme kunci elektronik tiap locker         |
| Sensor magnet (reed switch) | 4 unit                                     | Deteksi pintu terbuka/tertutup                 |
| Adaptor 12V                 | Switching, arus cukup untuk 4 solenoid     | Suplai daya solenoid                           |
| Step-down buck converter    | 12V → 5V                                   | Suplai daya ESP32 dari sumber sama             |
| Diode 1N4007                | 4-8 unit                                   | Proteksi flyback dari beban induktif solenoid  |
| Terminal block              | Screw terminal 2 jalur                     | Titik pembagi daya dari adaptor ke 2 jalur     |
| Barcode/QR stiker           | Cetak, 1 per locker                        | Berisi link web unik ke halaman kontrol locker |
| Casing/rangka locker        | Lemari 4 pintu 2 susun                     | Struktur fisik locker                          |
| Server backend              | Hosting internet (VPS/cloud kecil)         | Menjalankan API, database sesi sewa & locker   |

Detail harga ada di RAB terpisah (`hardware/RAB.xlsx`).

---

## 7. Kebutuhan Software / Tools Pengembangan

| Tools                                                     | Fungsi                                                        | Status                |
| --------------------------------------------------------- | ------------------------------------------------------------- | --------------------- |
| Arduino IDE / PlatformIO                                  | Development firmware ESP32 (polling + kontrol relay + sensor) | ⏳ Belum dikonfirmasi |
| Backend framework (mis. Node.js/Express)                  | Membangun REST API (sesi sewa, kode unik, dashboard)          | ⏳ Belum diputuskan   |
| Database (mis. SQLite/MySQL/PostgreSQL)                   | Menyimpan data sesi sewa, status locker, hash kode unik       | ⏳ Belum diputuskan   |
| Hosting backend (VPS/cloud kecil)                         | Supaya backend bisa diakses dari internet                     | ⏳ Belum diputuskan   |
| HTML/CSS/JS atau framework ringan (mis. tanpa build step) | Halaman web user & dashboard petugas                          | ⏳ Belum diputuskan   |
| Git                                                       | Version control                                               | ⏳ Belum dikonfirmasi |
| VS Code                                                   | Editor sehari-hari                                            | ⏳ Belum dikonfirmasi |

---

## 8. Alur Pengerjaan Proyek

1. **Riset & finalisasi konsep** — alur scan langsung, kode unik, sensor magnet _(sudah selesai)_
2. **Elisitasi kebutuhan** — wawancara 4 stakeholder (pengguna akhir, pengelola aset, IT, keamanan/kebersihan) + JAD dengan dosen pengampu _(materi wawancara sudah dibuat, lihat `docs/elisitasi/`)_
3. **Pengadaan komponen & alat** — beli ESP32, relay, solenoid, sensor magnet, adaptor, bahan casing
4. **Setup backend & hosting** — rancang skema database (rental, locker, kode unik ter-hash), bangun endpoint sesuai `docs/API.md`, siapkan hosting yang bisa diakses internet
5. **Bench test firmware** — uji 1 relay + 1 solenoid + 1 sensor magnet dulu, pastikan polling ke backend & pelaporan event pintu berjalan benar
6. **Bangun halaman web** — form sewa, tampilan kode unik, input kode unik, dashboard petugas
7. **Integrasi ujung-ke-ujung** — dari scan barcode sampai locker terbuka, tertutup otomatis, dan sesi tercatat benar
8. **Uji 4 unit locker sekaligus** — pastikan tidak ada locker yang salah terbuka / bentrok status, uji race condition
9. **Rakit casing/mekanik fisik** — pasang solenoid, relay, sensor magnet dalam struktur locker yang aman
10. **Uji skenario tepi** — pintu tidak ditutup (timeout), kode salah berkali-kali (rate limit), 2 device scan bersamaan
11. **Simulasi penggunaan oleh orang awam** — minta orang lain coba alur lengkap tanpa instruksi
12. **Deploy prototipe** untuk demo/pengujian nyata di kampus

---

## 9. Kebutuhan Alat/Perkakas (Tools Fisik)

| Alat                                  | Fungsi                                                       |
| ------------------------------------- | ------------------------------------------------------------ |
| Solder + timah                        | Menyambung kabel relay, solenoid, sensor magnet, dan ESP32   |
| Multimeter                            | Cek tegangan, kontinuitas kabel, troubleshooting rangkaian   |
| Obeng set (plus/minus, kecil)         | Merakit casing locker dan mengencangkan terminal             |
| Bor kecil / cutter                    | Membuat lubang pemasangan solenoid, sensor magnet, dan kabel |
| Kabel jumper (male-female, male-male) | Wiring sementara saat bench test                             |
| Breadboard                            | Uji coba rangkaian sebelum dirakit permanen                  |
| Laptop + kabel USB                    | Upload firmware, development backend & web                   |
| Isolasi/heat shrink tube              | Mengamankan sambungan kabel                                  |
| Printer stiker/label                  | Mencetak barcode/QR untuk ditempel di tiap locker            |

---

## 10. Pertimbangan Tambahan

- **Akuntabilitas tanpa akun permanen** — karena identitas cuma nama + no HP per sesi, penting memastikan data ini tersimpan cukup untuk investigasi kalau ada masalah (barang hilang, dsb), meski tidak ada login jangka panjang
- **Keamanan kode unik** — disimpan ter-hash, ditampilkan hanya 1 kali, dan dibatasi percobaan salah (rate limit) supaya tidak mudah ditebak
- **Rencana pembayaran masa depan** — saat ini prototipe kampus belum ada pembayaran; kalau nanti ditambahkan, alurnya direncanakan tetap dibayar di akhir sesi (saat mengakhiri sewa), bukan di muka
- **Koneksi firmware-backend terputus** — karena firmware bergantung pada polling ke internet, perlu dipikirkan bagaimana perilaku locker kalau koneksi internet di titik locker terputus sementara (retry otomatis, indikator status ke user)
- **Keamanan fisik solenoid fail-secure** — pastikan solenoid benar-benar default terkunci saat listrik mati
- **Beban di server backend** — karena backend publik di internet, perlu dipikirkan proteksi dasar (rate limiting per IP, dsb) supaya tidak mudah disalahgunakan orang luar yang menemukan pola URL locker

---

## 11. Status Proyek

- [x] Konsep alur sewa tanpa akun (scan → form nama/no HP → kode unik → locker terbuka)
- [x] Model sesi seperti parkir: durasi dihitung dari waktu pakai
- [x] Mekanisme kunci: solenoid + sensor magnet (auto-lock saat pintu tertutup)
- [x] Alur ambil barang dengan pilihan lanjut/akhiri sewa
- [x] Mitigasi pintu tidak tertutup: timeout 2 menit + dashboard petugas
- [x] Keputusan arsitektur firmware: ESP32 polling ke backend (karena backend hosting internet)
- [x] Keputusan tidak pakai app Flutter — sepenuhnya berbasis web
- [x] Skala prototipe: 4 unit locker
- [x] Stakeholder & teknik elisitasi teridentifikasi, materi wawancara sudah dibuat
- [ ] Setup hosting backend & database
- [ ] Kontrak endpoint API detail (draft ada di `docs/API.md`, interval polling & beberapa detail masih perlu dikonfirmasi tim)
- [ ] Pengembangan firmware (polling + kontrol relay + sensor magnet)
- [ ] Pengembangan halaman web (form sewa, kode unik, dashboard petugas)
- [ ] Desain casing/mekanik fisik locker
- [ ] Pengujian skenario tepi (timeout, race condition, rate limit kode)
- [ ] Pengujian end-to-end 4 unit locker
- [ ] Pelaksanaan wawancara & JAD dengan stakeholder
