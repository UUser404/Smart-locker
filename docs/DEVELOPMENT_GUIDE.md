# Dokumentasi Konsep — Smart Locker IoT

## 1. Ringkasan Proyek

Smart Locker adalah sistem penyewaan locker otomatis: tiap unit locker punya **barcode/QR unik**, dan proses sewa dikendalikan lewat **app Android (Flutter)** yang terhubung ke backend server dan firmware microcontroller.

Alur inti:

1. User **mendaftar** akun ke sistem Smart Locker.
2. User memesan locker → sistem membuat sesi sewa. **Model sesi seperti parkir**: tidak ada durasi ditentukan di awal, timer mulai jalan begitu locker dibuka (scan-in).
3. App menampilkan **scanner** (memakai kamera HP, bukan alat scanner fisik terpisah).
4. User scan barcode di locker fisik pilihannya.
5. Kalau barcode valid & locker tersedia → sistem mengirim perintah buka ke solenoid locker tersebut, sesi sewa jadi **aktif**, waktu mulai (`started_at`) dicatat.
6. Selama locker dipakai, app menampilkan durasi berjalan (naik terus, seperti tiket parkir). Saat user mengakhiri sewa lewat app, locker dibuka sekali lagi untuk pengambilan barang, dan **total durasi pakai baru dihitung di titik ini** (dari `started_at` sampai saat itu), lalu locker kembali berstatus kosong.

Dibangun sebagai project pembelajaran IoT & pemrograman platform mobile (kontrol solenoid, koordinasi backend-firmware-app Flutter), dengan skala **prototipe 4 unit locker**.

---

## 2. Analisis 5W1H

| Aspek     | Penjelasan                                                                                                                                                                                           |
| --------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **What**  | Sistem locker sewa otomatis berbasis barcode, dibuka lewat solenoid yang dikendalikan microcontroller                                                                                                |
| **Where** | Prototipe awal kemungkinan di area kampus/lingkup terbatas (LAN lokal antara app, backend, dan firmware)                                                                                             |
| **Who**   | User umum yang butuh penitipan barang sementara                                                                                                                                                      |
| **Why**   | Proyek belajar IoT (kontrol solenoid, sistem multi-komponen: backend + firmware + app)                                                                                                               |
| **When**  | Dipakai kapan saja selama sistem online; tiap sesi tetap 1x pakai, tapi lama pakainya bebas (dihitung, bukan ditentukan di awal)                                                                     |
| **How**   | Daftar akun → pesan locker (tanpa set durasi) → scan barcode via kamera HP → locker terbuka, timer mulai jalan → dipakai sesuka user → akhiri sesi saat ambil barang, total durasi dihitung otomatis |

---

## 3. Konsep Interaksi Pengguna

1. User membuka app/web Smart Locker, **mendaftar/login** ke sistem
2. User memilih **pesan locker** → sistem membuat sesi sewa berstatus `pending_scan` — **tidak ada input durasi**, karena modelnya seperti parkir (bayar/hitung sesuai lama pakai, bukan sewa waktu tetap)
3. App menampilkan **scanner kamera** → user mengarahkan kamera HP ke barcode di salah satu locker fisik yang masih kosong
4. Barcode berhasil dibaca → app mengirim hasil scan ke backend untuk divalidasi
5. Kalau valid & locker kosong → backend mengirim perintah buka ke firmware locker tersebut, solenoid terbuka sesaat, sesi sewa jadi **aktif**, waktu mulai (`started_at`) dicatat — ini titik "ambil tiket parkir"-nya
6. User memakai locker (menyimpan barang, menutup pintu — pintu otomatis terkunci lagi karena solenoid fail-secure)
7. Selama locker dipakai, app menampilkan **durasi berjalan** (terus naik, bukan countdown)
8. Untuk mengambil barang: user menekan tombol "akhiri sewa" di app → backend kirim perintah buka sekali lagi ke locker yang sama, **sekaligus menghitung total durasi pakai** dari `started_at` sampai saat itu → user ambil barang → sesi ditandai selesai, locker kembali kosong

Catatan: karena tidak ada batas durasi tetap, perlu didiskusikan apakah tetap ada batas wajar/maksimum sesi aktif (lihat bagian 10).

---

## 4. Konsep Alur Sistem (End-to-End)

```
[User daftar/login] --> [Pesan locker, pilih durasi]
        |
        v
[App tampilkan scanner kamera HP]
        |
        v
[User scan barcode locker fisik] --> [Backend validasi barcode & ketersediaan]
        |
        v (valid)
[Backend kirim perintah buka] --> [Firmware ESP32 locker] --> [Solenoid terbuka sesaat]
        |
        v
[Sesi sewa aktif, durasi berjalan ditampilkan di app]
        |
        v
[User akhiri sewa] --> [Backend hitung total durasi & kirim perintah buka lagi] --> [User ambil barang]
        |
        v
[Locker kembali berstatus kosong]
```

**Perbedaan pola dibanding project dispenser sebelumnya:**

- Dispenser: ESP32 berdiri sendiri sebagai access point + web server (semua logic ada di 1 alat)
- Smart Locker: perlu **backend server terpusat** karena ada konsep akun user, riwayat sewa, dan validasi barcode yang harus konsisten lintas 4 unit locker — firmware ESP32 di tiap locker hanya "eksekutor" perintah buka, bukan pemegang keputusan

---

## 5. Arsitektur Sistem

- **Backend server:** single source of truth untuk akun user, sesi sewa, dan status tiap locker (kosong/disewa/pending_scan). Menangani registrasi, login, validasi barcode, dan mengirim perintah buka ke firmware yang tepat.
- **Firmware (microcontroller per locker atau 1 controller pusat untuk 4 locker):** menerima perintah buka dari backend, mengaktifkan relay → solenoid door lock selama durasi pulsa tertentu, lalu otomatis terkunci lagi (fail-secure)
- **App Android (Flutter):** tempat user mendaftar, memesan locker, dan scan barcode lewat **kamera HP** (pakai package scanner seperti `mobile_scanner`) — juga menampilkan status & durasi berjalan sesi sewa
- **Barcode:** ditempel fisik di tiap locker, isinya ID unik locker; keabsahan & kecocokan dengan sesi sewa divalidasi di backend
- **Solenoid door lock:** dikontrol lewat relay dari microcontroller, skema fail-secure (default terkunci, terbuka hanya saat menerima sinyal)

---

## 6. Kebutuhan Komponen (Draft Awal)

| Komponen                 | Spesifikasi                                                                         | Fungsi                                       |
| ------------------------ | ----------------------------------------------------------------------------------- | -------------------------------------------- |
| Microcontroller (ESP32)  | 1 unit (kontrol 4 relay/solenoid) atau 4 unit (1 per locker) — **perlu diputuskan** | Menerima perintah buka & mengontrol solenoid |
| Relay module             | 4 channel, aktif LOW                                                                | Switch tiap solenoid                         |
| Solenoid door lock       | 12V, fail-secure, 4 unit                                                            | Mekanisme kunci elektronik tiap locker       |
| Adaptor 12V              | Switching, arus cukup untuk 4 solenoid                                              | Suplai daya solenoid                         |
| Step-down buck converter | 12V → 5V                                                                            | Suplai daya microcontroller dari sumber sama |
| Barcode/QR stiker        | Cetak, 1 per locker                                                                 | Identitas unik tiap locker                   |
| Casing/rangka locker     | Kayu/besi/akrilik, 4 kompartemen                                                    | Struktur fisik locker                        |
| Server backend           | Bisa berupa laptop/PC atau layanan cloud kecil                                      | Menjalankan API, database user & sesi sewa   |

---

## 7. Kebutuhan Software / Tools Pengembangan

| Tools                                                     | Fungsi                                                      | Status                                             |
| --------------------------------------------------------- | ----------------------------------------------------------- | -------------------------------------------------- |
| Arduino IDE / PlatformIO                                  | Development firmware ESP32                                  | ⏳ Belum dikonfirmasi                              |
| Backend framework (mis. Node.js/Express, atau lainnya)    | Membangun REST API (auth, rental, validasi barcode)         | ⏳ Belum diputuskan                                |
| Database (mis. SQLite/MySQL/Firebase)                     | Menyimpan data user, sesi sewa, status locker               | ⏳ Belum diputuskan                                |
| Flutter SDK                                               | Membangun app Android (UI, scan barcode, status sewa)       | ✅ Sudah diputuskan (reuse dari project dispenser) |
| Package `mobile_scanner` atau `qr_code_scanner` (Flutter) | Membaca barcode/QR lewat kamera HP di app                   | ⏳ Belum dipilih salah satu                        |
| Package `http` / `dio` (Flutter)                          | Komunikasi HTTP app ke backend                              | ⏳ Belum dipilih salah satu                        |
| Android Studio + Android SDK                              | Build & jalankan app Flutter di Android (emulator/HP fisik) | ⏳ Belum dikonfirmasi                              |
| Git                                                       | Version control                                             | ⏳ Belum dikonfirmasi                              |
| VS Code                                                   | Editor sehari-hari                                          | ⏳ Belum dikonfirmasi                              |

---

## 8. Alur Pengerjaan Proyek

1. **Riset & finalisasi konsep** — alur sewa, validasi barcode, mekanisme solenoid _(sudah selesai)_
2. **Putuskan arsitektur controller** — 1 microcontroller pusat untuk 4 locker, atau 1 microcontroller per locker
3. **Pengadaan komponen & alat** — beli microcontroller, relay, solenoid, adaptor, bahan casing
4. **Setup backend** — rancang skema database (user, rental, locker), bangun endpoint sesuai `docs/API.md`
5. **Bench test firmware** — uji 1 relay + 1 solenoid dulu (nyala/kunci sesuai perintah dari backend)
6. **Bangun app Flutter** — UI daftar/login, pesan locker, scanner barcode kamera HP, tampilan durasi berjalan
7. **Integrasi ujung-ke-ujung** — dari daftar akun sampai locker terbuka setelah scan barcode
8. **Uji 4 unit locker sekaligus** — pastikan tidak ada locker yang salah terbuka / bentrok status
9. **Rakit casing/mekanik fisik** — pasang solenoid, relay, wiring dalam struktur locker yang aman
10. **Uji keamanan dasar** — coba skenario barcode dipalsukan/di-foto ulang, sesi sewa kedaluwarsa, dsb
11. **Simulasi penggunaan oleh orang awam** — minta orang lain coba alur lengkap tanpa instruksi
12. **Deploy prototipe** untuk demo/pengujian nyata

---

## 9. Kebutuhan Alat/Perkakas (Tools Fisik)

| Alat                                  | Fungsi                                                     |
| ------------------------------------- | ---------------------------------------------------------- |
| Solder + timah                        | Menyambung kabel relay, solenoid, dan microcontroller      |
| Multimeter                            | Cek tegangan, kontinuitas kabel, troubleshooting rangkaian |
| Obeng set (plus/minus, kecil)         | Merakit casing locker dan mengencangkan terminal           |
| Bor kecil / cutter                    | Membuat lubang pemasangan solenoid & kabel di casing       |
| Kabel jumper (male-female, male-male) | Wiring sementara saat bench test                           |
| Breadboard                            | Uji coba rangkaian sebelum dirakit permanen                |
| Laptop + kabel USB                    | Upload firmware, development backend & app                 |
| Isolasi/heat shrink tube              | Mengamankan sambungan kabel                                |
| Printer stiker/label                  | Mencetak barcode/QR untuk ditempel di tiap locker          |

---

## 10. Pertimbangan Tambahan

- **Keamanan barcode** — barcode yang isinya cuma ID polos berisiko dipalsukan/difoto ulang orang lain; perlu dipikirkan apakah perlu barcode dinamis/signed, atau minimal barcode hanya valid dipasangkan dengan sesi sewa yang sedang `pending_scan` milik user yang login
- **Batas wajar durasi sesi** — karena tidak ada durasi tetap (mirip parkir), perlu dipikirkan apakah tetap ada batas maksimum sesi aktif (mis. auto-notifikasi kalau sudah sangat lama, atau kebijakan khusus kalau user "hilang tiket"/lupa mengakhiri sesi) — ini masih terbuka untuk didiskusikan tim
- **Koneksi backend-firmware terputus** — kalau backend tidak bisa menjangkau firmware locker saat mau kirim perintah buka, perlu ada retry/error handling & notifikasi ke user supaya tidak menggantung
- **Skalabilitas jumlah locker** — arsitektur berbasis backend dipilih justru supaya nanti gampang ditambah lebih dari 4 unit tanpa mengubah alur inti
- **Keamanan fisik solenoid fail-secure** — pastikan solenoid benar-benar default terkunci saat listrik mati, supaya locker tidak semua terbuka kalau ada gangguan daya

---

## 11. Status Proyek

- [x] Konsep alur sewa (daftar → pesan → scan barcode → locker terbuka → durasi → ambil barang)
- [x] Keputusan mekanisme kunci: solenoid door lock dikontrol microcontroller
- [x] Keputusan metode scan: kamera HP (bukan scanner fisik terpisah)
- [x] Skala prototipe: 4 unit locker
- [x] Model sesi sewa seperti parkir: durasi dihitung dari waktu pakai, bukan ditentukan di awal
- [ ] Keputusan arsitektur controller (1 pusat vs 1 per locker)
- [ ] Desain skema database & backend
- [ ] Kontrak endpoint API detail (draft awal sudah ada di `docs/API.md`, beberapa poin masih perlu dikonfirmasi tim)
- [ ] Pengembangan firmware kontrol solenoid
- [ ] Pengembangan app/web (scanner kamera, countdown, dsb)
- [ ] Desain casing/mekanik fisik locker
- [ ] Kebijakan penanganan sewa lewat waktu
- [ ] Pengujian keamanan barcode
- [ ] Pengujian end-to-end 4 unit locker
