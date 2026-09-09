# Dokumentasi Konsep — Smart Dispenser IoT (3 Rasa)

## 1. Ringkasan Proyek

Smart Dispenser adalah alat penuang minuman otomatis dengan **3 saluran rasa** (susu, kopi, teh, atau varian lain sesuai kebutuhan acara), yang dikendalikan tamu langsung dari HP mereka.

Ada **dua jalur kontrol** yang disediakan:

1. **Captive portal (web based)** — tamu cukup connect ke WiFi dispenser, interface kontrol muncul otomatis tanpa install apa pun.
2. **App Flutter (native, Android)** — kontrol alternatif, dikembangkan sebagai bagian dari tugas mata kuliah **Pemrograman Berbasis Platform**. App ini connect ke ESP32 lewat WiFi (HTTP) dan memakai endpoint yang sama dengan captive portal.

Proyek ini dibangun sebagai **sarana belajar IoT/elektronika sekaligus pemrograman platform (mobile)**, dengan target penggunaan nyata di **acara/event** (pernikahan, gathering, bazar) untuk **tamu umum**.

---

## 2. Analisis 5W1H

| Aspek     | Penjelasan                                                                                                                                                             |
| --------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **What**  | Dispenser otomatis 3 rasa, dikendalikan lewat web interface (captive portal) atau app Flutter                                                                          |
| **Where** | Venue acara (pernikahan, gathering, bazar) — spot self-service minuman di area refreshment                                                                             |
| **Who**   | Tamu umum yang hadir di acara, mayoritas awam teknologi                                                                                                                |
| **Why**   | Proyek belajar IoT/elektronika & Pemrograman Berbasis Platform, sekaligus punya nilai guna nyata & portofolio                                                          |
| **When**  | Sepanjang durasi acara, dengan potensi traffic tinggi di jam tertentu (resepsi/jam makan)                                                                              |
| **How**   | Tamu connect WiFi → popup interface otomatis (atau buka app Flutter) → geser pilih rasa → tahan gambar / tekan Start untuk menuang → lepas / tekan Stop untuk berhenti |

---

## 3. Konsep Interaksi Pengguna

1. Tamu menyalakan WiFi di HP, memilih SSID dispenser (mis. `SmartDispenser`) — **atau** membuka app Flutter yang sudah terhubung ke WiFi dispenser
2. HP otomatis memunculkan popup captive portal berisi UI pilih rasa (fallback: buka browser manual ke `192.168.4.1`), atau tamu langsung pakai app Flutter
3. Tamu **menggeser** gambar pada layar untuk berpindah rasa (carousel 3 rasa) — perilaku sama di web maupun app
4. Untuk menuang:
   - **Cara 1:** tekan-tahan gambar rasa → pompa menyala selama ditahan → lepas → pompa mati
   - **Cara 2:** tap tombol **Start** → pompa menyala terus, tombol berubah jadi **Stop** → tap **Stop** untuk menghentikan
5. Hanya **1 pompa aktif** dalam satu waktu (tidak ada pencampuran rasa) — berlaku lintas jalur kontrol (web maupun app)
6. Ada tombol **Menu** di samping tombol Start (fungsi lanjutan menyusul)

---

## 4. Konsep Alur Cairan (Mekanik)

```
[Wadah Rasa A] --selang--> [Pompa dinamo A] --selang--> ┐
[Wadah Rasa B] --selang--> [Pompa dinamo B] --selang--> ┼--> [Nozzle keluaran / gelas tamu]
[Wadah Rasa C] --selang--> [Pompa dinamo C] --selang--> ┘
```

- Setiap wadah rasa punya jalur pompa & selang sendiri (independen)
- Pompa dinamo langsung mendorong cairan (bukan sistem tekanan udara)
- Ketiga selang bisa digabung ke 1 titik keluaran (fitting Y/T) atau dibuat 3 nozzle terpisah — pilihan desain casing

**Referensi pola serupa di komunitas maker:**

- Pola kontrol pompa via relay antara mikrokontroler dan pompa 12V adalah pendekatan standar untuk proyek seperti mesin cocktail atau mesin kopi DIY
- Proyek vending machine berbasis ESP32 lain menggunakan modul relay multi-channel + pompa mini DC dengan ESP32 sebagai controller utama
- Pendekatan alternatif (tidak dipakai di sini) menggunakan pompa udara untuk mendorong cairan dari luar wadah tanpa kontak langsung dengan pompa

---

## 5. Arsitektur Sistem

- **Mikrokontroler:** ESP32 (AP mode + DNS server + Web server berjalan bersamaan)
- **Captive portal:** ESP32 jadi Access Point, semua domain di-resolve ke IP ESP32 sehingga HP tamu otomatis memunculkan popup interface
- **Kontrol pompa:** 3× relay module (aktif LOW), masing-masing switch 1 pompa dinamo 12V
- **Sumber daya:** Adaptor 12V terpisah untuk pompa, ESP32 disuplai lewat step-down 12V→5V dari sumber yang sama (ground disatukan)
- **UI Web:** Halaman web (HTML/CSS/JS) yang disajikan langsung dari ESP32, berisi carousel swipe rasa + tombol Start/Stop + tombol Menu
- **UI App (baru):** App Flutter (Android) sebagai kontrol alternatif — connect ke WiFi ESP32, komunikasi lewat HTTP request ke endpoint yang sama dipakai captive portal (mis. `GET /pour?flavor=milk`, `GET /stop`)
- **Prinsip desain:** ESP32 tetap 1 sumber kebenaran (single source of truth) untuk status pompa & flavor aktif, supaya web dan app tidak saling konflik saat dipakai bersamaan

---

## 6. Kebutuhan Komponen (Draft Awal)

| Komponen                  | Spesifikasi                    | Fungsi                             |
| ------------------------- | ------------------------------ | ---------------------------------- |
| ESP32 DevKit V1           | 30/38 pin                      | Controller utama, AP + web server  |
| Relay module 3 channel    | 5V, aktif LOW, opto-isolated   | Switch tiap pompa                  |
| Pompa dispenser dinamo    | 12V, 3 unit                    | Pemompa cairan per rasa            |
| Adaptor 12V               | Switching, 3A+                 | Suplai daya pompa                  |
| Step-down buck converter  | 12V → 5V (LM2596 atau sejenis) | Suplai daya ESP32 dari sumber sama |
| Selang silikon food grade | Sesuai nozzle pompa            | Saluran cairan                     |
| Wadah penampung           | Galon/jerigen kecil, 3 unit    | Penyimpanan tiap rasa              |

---

## 7. Kebutuhan Software / Tools Pengembangan

| Tools                             | Fungsi                                                                                   | Status                                                                                       |
| --------------------------------- | ---------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------- |
| Flutter SDK                       | Membangun app kontrol (Android)                                                          | 🔄 Sedang instalasi                                                                          |
| Android Studio + Android SDK      | Build & jalankan app Flutter di Android (emulator/HP fisik)                              | 🔄 SDK & Emulator sudah ada, cmdline-tools masih perlu diinstall, lisensi belum diverifikasi |
| VS Code + extension Flutter/Dart  | Editor sehari-hari untuk coding                                                          | ⏳ Belum dikonfirmasi                                                                        |
| Git                               | Version control, dibutuhkan Flutter SDK                                                  | ⏳ Belum dikonfirmasi                                                                        |
| Visual Studio (Desktop C++ tools) | **Tidak dibutuhkan** — hanya perlu kalau mau build target Windows desktop, bukan Android | ❌ Skip                                                                                      |

---

## 8. Alur Pengerjaan Proyek

1. **Riset & finalisasi konsep** — menentukan interaksi UI, mekanisme captive portal, dan alur cairan _(sudah selesai)_
2. **Pengadaan komponen & alat** — beli ESP32, relay, pompa, adaptor, selang, wadah, dan perkakas pendukung
3. **Setup environment development Flutter** _(sedang berjalan)_ — install Flutter SDK, Android Studio (SDK + cmdline-tools + AVD), VS Code
4. **Uji coba modul per bagian (bench test)**:
   - Uji ESP32 sebagai Access Point + captive portal (tanpa pompa dulu)
   - Uji 1 relay + 1 pompa dengan air biasa (pastikan nyala/mati sesuai perintah)
   - Uji web UI (swipe, hold-to-pour, tombol Start/Stop) di HP
5. **Bangun app Flutter** — UI carousel rasa, tombol Start/Stop, hold-to-pour, koneksi HTTP ke endpoint ESP32
6. **Integrasi 3 saluran** — sambungkan ketiga pompa & relay sekaligus ke satu firmware, uji hanya 1 pompa aktif dalam satu waktu
7. **Uji alur cairan penuh** — dari wadah → pompa → selang → nozzle, cek kebocoran & kecepatan alir
8. **Desain & rakit casing/mekanik** — tempatkan wadah, pompa, ESP32, relay, dan kabel dalam satu unit yang rapi dan aman
9. **Uji coba higienitas & kebersihan** — pastikan selang/nozzle mudah dilepas-pasang untuk dibersihkan
10. **Simulasi penggunaan oleh orang awam** — minta orang lain coba tanpa diberi instruksi (baik lewat web maupun app), catat kebingungan yang muncul untuk perbaikan UI
11. **Uji coba multi-user/antrian** — coba 2 device connect bersamaan (kombinasi web & app), pastikan tidak terjadi konflik pompa
12. **Gladi bersih di lokasi mendekati kondisi acara** — cek jangkauan WiFi, daya tahan baterai/adaptor, dan ketahanan alat selama durasi acara
13. **Deploy di acara sesungguhnya**

---

## 9. Kebutuhan Alat/Perkakas (Tools Fisik)

| Alat                                  | Fungsi                                                               |
| ------------------------------------- | -------------------------------------------------------------------- |
| Solder + timah                        | Menyambung kabel ke relay, pompa, dan ESP32                          |
| Multimeter                            | Cek tegangan, kontinuitas kabel, dan troubleshooting rangkaian       |
| Obeng set (plus/minus, kecil)         | Merakit casing dan mengencangkan terminal                            |
| Cutter/gunting                        | Memotong selang silikon sesuai panjang kebutuhan                     |
| Lem tembak (glue gun) / lem silikon   | Merekatkan komponen di casing, menutup celah agar tidak bocor        |
| Kabel jumper (male-female, male-male) | Wiring sementara saat tahap bench test                               |
| Breadboard                            | Uji coba rangkaian sebelum dirakit permanen                          |
| Laptop + kabel USB                    | Upload firmware ke ESP32, monitoring serial, development app Flutter |
| Isolasi/heat shrink tube              | Mengamankan sambungan kabel                                          |
| Wadah/box uji (ember kecil)           | Menampung cairan uji coba tanpa harus pakai wadah asli dulu          |

---

## 10. Pertimbangan Tambahan (Konteks Acara & Tamu Umum)

Karena target pemakaian adalah **acara dengan tamu umum yang awam teknologi**, ada beberapa hal di luar kode/wiring yang perlu direncanakan:

- **Higienitas** — selang & nozzle harus mudah dilepas-pasang untuk dibersihkan; nozzle idealnya tidak tersentuh langsung oleh gelas tamu
- **Kapasitas wadah** — untuk traffic tamu acara, wadah 5–19 liter lebih realistis daripada botol kecil
- **Antrian / multi-user** — karena hanya ada 1 hotspot dengan 1 pompa aktif, perlu mekanisme sederhana (misal lock status) untuk menghindari konflik kalau ada tamu connect bersamaan lewat web **maupun** app
- **Casing/tampilan fisik** — karena dipakai di acara, tampilan luar dispenser turut dinilai, bukan hanya fungsinya
- **Konsistensi UX lintas platform** — pengalaman pakai app Flutter dan web captive portal sebaiknya terasa mirip (layout carousel, tombol) supaya tamu tidak bingung kalau pindah jalur kontrol

---

## 11. Status Proyek

- [x] Konsep interaksi pengguna (swipe rasa, hold/tombol menuang)
- [x] Konsep alur cairan (wadah → pompa → nozzle)
- [x] Firmware awal (captive portal + web UI + kontrol relay) — draft pertama sudah dibuat
- [x] Keputusan menambah app Flutter sebagai kontrol alternatif (tugas Pemrograman Berbasis Platform)
- [ ] Setup environment development Flutter (SDK, Android Studio, VS Code) — _sedang berjalan_
- [ ] Desain wiring diagram detail
- [ ] Desain endpoint HTTP di firmware ESP32 yang dipakai bersama (web + app)
- [ ] Pengembangan app Flutter (UI + koneksi ke ESP32)
- [ ] Desain casing/mekanik fisik
- [ ] Penanganan multi-user/antrian
- [ ] Pengujian hardware end-to-end
