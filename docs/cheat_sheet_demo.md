# Cheat Sheet Demo — Smart Locker IoT

> Satu halaman yang harus dibuka saat demo. Kalau ada masalah, langsung cek ke sini.

---

## 1. URL & Akses

| Item | URL / Nilai |
|---|---|
| **Backend production** | `https://smart-locker-backend-a2ck.onrender.com` |
| **Health check** | `https://smart-locker-backend-a2ck.onrender.com/` |
| **GitHub repo** | `https://github.com/UUser404/Smart-locker` |
| **Branch aktif** | `feature/firmware` |
| **Firebase Console** | `https://console.firebase.google.com/project/smart-locker-project-45bac` |
| **Render Dashboard** | `https://dashboard.render.com` |

### Akun Testing

| Username | Password | Role | Untuk |
|---|---|---|---|
| `admin` | `admin123` | admin | Akses reports, resolve locker |
| `petugas1` | `petugas123` | petugas | Akses dashboard locker, resolve |

### Device Token (Firmware)
`70cd4fbd2fd930b1844d7dcff3bb9270`

Header: `X-Device-Token: 70cd4fbd2fd930b1844d7dcff3bb9270`

---

## 2. Persiapan 10 Menit Sebelum Demo

### a. Hangatkan backend (WAJIB)
Render free tier tidur setelah 15 menit idle. Bangunkan:
* Buka di browser: `https://smart-locker-backend-a2ck.onrender.com/`
* Tunggu sampai muncul:
```json
{
  "status": "ok",
  "message": "Smart Locker backend jalan"
}
```
> ⏱ Bisa 30-60 detik. Jangan panik.

### b. Cek firmware status
1. Colok ESP32 ke laptop (power, tidak perlu upload)
2. Buka VS Code, terminal di `firmware/smart-locker`
3. Jalankan: `pio device monitor`
4. Harus muncul:
   ```text
   [Sync] OK
   [QR] Locker 0 token: xxxxxx
   ```
5. Kalau `[Sync] HTTP 401` → device token salah.
6. Kalau tidak ada log → cabut-colok USB ESP32.

### c. Cek koneksi WiFi kampus
Firmware harus dapat IP. Lihat Serial Monitor:
```text
[WiFi] Terhubung. IP: 10.10.30.xxx
```
* Kalau IP `0.0.0.0` atau `[WiFi] Timeout` → ESP32 belum terdaftar di whitelist MAC kampus. Hubungi IT.

### d. Siapkan Thunder Client
Buka VS Code → Thunder Client. Pastikan request berikut sudah ada:
* `POST /api/auth/login` → body admin
* `GET /api/admin/lockers` → Bearer token
* `POST /api/admin/lockers/locker_01/resolve`

---

## 3. Alur Demo (15 menit)

### SKENARIO 1: Lihat Status Locker (1 menit)
* **Tujuan:** Tunjukkan semua locker statusnya empty.
* **Langkah:**
  1. Thunder Client → `POST /api/auth/login`
     ```json
     {
       "username": "admin",
       "password": "admin123"
     }
     ```
  2. Copy token dari response.
  3. `GET /api/admin/lockers` → Auth: Bearer `<token>`
  4. Response: 4 locker, semua `empty` ✅
* **Yang dijelaskan:** *"Backend jadi single source of truth, semua locker konsisten, real-time."*

---

### SKENARIO 2: Sewa Locker via Web (3 menit)
* **Tujuan:** Tunjukkan alur user sewa locker end-to-end.
* **Prasyarat:** Web Reza sudah deploy. Kalau belum, pakai Thunder Client manual.
* **Langkah:**
  1. Buka web di HP/laptop.
  2. Scan QR locker (tampil di TFT locker 0).
  3. Isi nama & no HP.
  4. Klik "Sewa".
  5. Dapat kode unik — **TULIS di papan/notepad**.
  6. Locker terbuka (relay klik, pintu bisa dibuka manual).
  7. Tutup pintu → sensor deteksi → sesi mulai.
* **Yang dijelaskan:** *"Tanpa akun, tanpa install. Hanya scan QR dinamis, isi nama & no HP."*
* **Kalau web belum siap:** demo via Thunder Client:
  ```text
  POST /api/lockers/locker_01/rent
  Body: { "nama": "Demo", "no_hp": "08123456789", "token": "<dari TFT>" }
  ```

---

### SKENARIO 3: Ambil Barang & Akhiri Sewa (2 menit)
* **Tujuan:** Tunjukkan flow user ambil barang.
* **Langkah:**
  1. Scan QR lagi di locker yang sama.
  2. Input kode unik tadi.
  3. Pilih "Ambil Barang & Akhiri Sewa".
  4. Locker terbuka.
  5. Ambil barang, tutup pintu.
  6. Tunggu 5 detik — sesi selesai, locker balik empty.
* **Cek di Thunder Client:**
  ```text
  GET /api/rentals/<rental_id>/status
  ```
  Harus balas status: `"completed"` + `total_duration_seconds`.
* **Yang dijelaskan:** *"Durasi dihitung otomatis. Sesi selesai saat pintu ditutup, bukan saat user klik tombol."*

---

### SKENARIO 4: QR Dinamis (1 menit)
* **Tujuan:** Tunjukkan QR di TFT berubah tiap 5 detik.
* **Langkah:**
  1. Arahkan kamera HP ke TFT locker.
  2. Foto QR, tunggu 5 detik, foto lagi.
  3. Bandingkan — token beda.
* **Yang dijelaskan:** *"QR dinamis cegah sewa jarak jauh. Siapa pun yang screenshot QR cuma valid 60 detik. Setelah itu harus scan ulang dari layar fisik."*

---

### SKENARIO 5: Timeout Detection (2 menit)
* **Tujuan:** Tunjukkan auto-deteksi pintu tidak tertutup.
* **Langkah:**
  1. Sewa locker (scan + rent).
  2. Buka pintu, JANGAN tutup.
  3. Tunggu 2 menit (bisa dipercepat dengan ubah `TIMEOUT_MS` sementara).
  4. Backend auto-flag `needs_attention`.
  5. Cek Thunder Client:
     ```text
     GET /api/admin/lockers
     ```
     Status locker = `needs_attention` ✅
  6. Push notification terkirim ke app petugas (kalau FCM aktif).
* **Yang dijelaskan:** *"Sistem deteksi sendiri locker bermasalah. Petugas dapat notifikasi tanpa harus cek manual."*

---

### SKENARIO 6: Petugas Resolve (2 menit)
* **Tujuan:** Tunjukkan flow petugas.
* **Langkah:**
  1. Login sebagai `petugas1`.
  2. Cek locker yang `needs_attention`.
  3. Klik "Resolve" → locker kembali `empty`, siap disewa ulang.
* **Via Thunder Client:**
  ```text
  POST /api/admin/lockers/locker_01/resolve
  Auth: Bearer <token petugas1>
  ```
  Response: `{ "status": "ok", "new_status": "empty" }`

---

### SKENARIO 7: Laporan Admin (2 menit)
* **Tujuan:** Tunjukkan data tersimpan & bisa dilaporkan.
* **Langkah:**
  1. Login admin.
  2. `GET /api/admin/reports/rentals`
  3. Response:
     ```json
     {
       "stats": {
         "total_rentals": N,
         "avg_duration_seconds": ...,
         "busiest_locker_id": "locker_01"
       },
       "rentals": [...]
     }
     ```
  4. Perhatikan: no_hp di-mask (`0812****89`).
* **Yang dijelaskan:** *"Semua sesi tercatat. Untuk audit/pengelola aset. No HP di-mask sebagian untuk privasi."*

---

### SKENARIO 8: Rate Limiter (1 menit)
* **Tujuan:** Tunjukkan proteksi kode unik.
* **Langkah:**
  1. Coba akses locker dengan kode salah 5x berturut-turut.
  2. Percobaan ke-5: `429 Too Many Requests`.
  3. Locker terkunci 5 menit.
* **Yang dijelaskan:** *"Kode unik disimpan dalam bentuk hash. Rate limiter cegah brute-force."*

---

## 4. Troubleshooting Cepat

* **Backend 500 / timeout**
  * *Gejala:* Semua endpoint balas 500.
  * *Cek:* Firestore quota exceeded.
  * *Solusi:* Buka Firebase Console → Usage. Kalau harian over → tunggu reset (07:00 UTC / 14:00 WIB). Kalau sering → hubungi Galuh (masalah rotator token).

* **Firmware tidak muncul di Serial Monitor**
  * *Gejala:* `pio device monitor` jalan tapi tidak ada log.
  * *Solusi:* Cabut-colok USB ESP32. Cek COM port (`dir` di Device Manager). Tekan tombol EN di board ESP32. Update `platformio.ini` kalau port berubah: `upload_port = COM10`.

* **Firmware HTTP 401**
  * *Gejala:* `[Sync] HTTP 401` di Serial Monitor.
  * *Solusi:* Cek `DEVICE_TOKEN` di `config.h`. Bandingkan dengan Firestore → `controllers/esp32_01.authToken`. Kalau beda, copy yang benar dari Firestore.

* **Firmware HTTP 404**
  * *Gejala:* `[Sync] HTTP 404 Cannot POST /api/firmware/esp32_01/sync`.
  * *Solusi:* Endpoint `/sync` belum deploy. Hubungi Galuh untuk deploy ulang.

* **QR tidak muncul di TFT**
  * *Gejala:* TFT blank atau putih.
  * *Cek:* Wiring SPI (`SCLK=18, MOSI=23, CS=4, DC=16, BLK=19`). `VCC=3.3V`, GND common. `RES` harus HIGH (colok 3.3V). Upload firmware dengan `ENABLE_TFT true`.

* **Locker tidak terbuka saat sewa**
  * *Gejala:* Sewa sukses, tapi solenoid tidak trigger.
  * *Cek:* Serial Monitor harus muncul `[Cmd] Locker X: UNLOCK`. Kalau muncul tapi relay tidak klik → wiring relay (`VCC`, `GND`, `IN`). Kalau tidak muncul → cek Firestore `pendingCommand: "unlock"`. Cek wiring solenoid + flyback diode.

* **Race condition (2 device scan sama)**
  * *Gejala:* Dua user scan locker yang sama, yang kedua dapat `409`. Ini normal.
  * *Response:*
    ```json
    { "status": "error", "message": "Locker sudah terisi" }
    ```
    User harus cari locker lain.

---

## 5. FAQ (Sering Ditanya Dosen)

* **Q: Kenapa ESP32 polling, bukan push?**  
  **A:** Backend di internet publik, ESP32 di jaringan lokal (di balik NAT). Backend tidak bisa connect ke ESP32. Jadi ESP32 yang inisiatif polling tiap 2 detik.

* **Q: Bagaimana kalau koneksi putus?**  
  **A:** Firmware retry otomatis dengan exponential backoff. State di backend tetap aman. Saat koneksi pulih, sync lanjut normal.

* **Q: Kenapa QR dinamis?**  
  **A:** QR statis bisa di-screenshot dan disalahgunakan untuk sewa jarak jauh. QR dinamis dengan token rotate 5 detik + valid 60 detik cegah itu.

* **Q: Kenapa pakai Firestore, bukan MySQL?**  
  **A:** Free tier cukup, realtime, tidak perlu setup server DB. Untuk prototipe kampus, cocok. Kalau production, pertimbangkan PostgreSQL.

* **Q: Bagaimana race condition dicegah?**  
  **A:** Firestore transaction di endpoint `/rent`. Request pertama commit occupied, request kedua baca state terbaru → ditolak `409`.

* **Q: Bagaimana keamanan kode unik?**  
  **A:** Hash SHA-256, tampil 1x saja. Rate limiter 5x gagal → lock 5 menit. Pesan error generik supaya tidak bisa ditebak.

* **Q: Bagaimana scaling ke lebih banyak locker?**  
  **A:** Arsitektur sudah support. Tambah `controllerId` baru di Firestore, tambah unit ESP32, semua sistem otomatis.

* **Q: Kenapa pakai endpoint `/sync`?**  
  **A:** Hemat request — gabung poll + report jadi 1 request. ESP32 lebih ringan. State pintu dideteksi backend dari perbandingan.

---

## 6. Tim & Kontak

| Nama | Scope | Kontak |
|---|---|---|
| Galuh | Backend & Firmware | (WA kamu) |
| Alfian | Hardware & Wiring | (WA Alfian) |
| Reza | Web & App Petugas | (WA Reza) |

---

## 7. Doa & Mentalitas

Yang harus diingat:
1. **Prep > improvisasi.** 10 menit persiapan hemat 30 menit panik.
2. Kalau error, **jelasin**. *"Ini karena X, solusinya Y"* lebih baik dari *"hmm kok error ya"*.
3. Dosen penguji tahu hardware IoT itu ribet. Mereka **tidak expect demo sempurna** — mereka expect pemahaman kamu.
4. Kalau benar-benar gagal demo, kamu masih punya:
   * Serial Monitor log (bukti firmware kerja)
   * Postman/Thunder Client history (bukti endpoint kerja)
   * Firestore data (bukti data tersimpan)
   * Dokumentasi lengkap