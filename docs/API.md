# Kontrak API — Smart Locker

Dokumen ini adalah **kontrak resmi** antara backend server, firmware ESP32 (kontrol solenoid & sensor magnet), dan web (dipakai user lewat scan barcode, dan petugas lewat dashboard).

> ⚠️ Kalau ada perubahan endpoint/format, update dokumen ini DULU sebelum ubah kode, lalu kabari bagian lain. Ini mencegah web, backend, dan firmware saling nggak sinkron.

Base URL backend: `https://<domain-backend>/api` (hosting internet, bukan LAN lokal)

> Catatan arsitektur: karena backend di-hosting di internet sementara ESP32 ada di jaringan lokal kampus, **arah komunikasi firmware terbalik dari desain awal** — ESP32 yang polling ke backend secara berkala, bukan backend yang memanggil IP ESP32 langsung (lihat bagian 5 & 6).
>
> **Update: QR dinamis.** QR di badan locker **tidak lagi statis**. Backend merotasi token per locker secara berkala dan menumpangkannya di response polling firmware (bagian 5), lalu firmware menampilkannya sebagai QR di layar TFT kecil pada locker (lihat `hardware/RAB.xlsx` item 1.12), ganti stiker cetak statis. Halaman web sekarang **membuka kamera & scan QR langsung di dalam web** (bukan lewat kamera bawaan HP membuka link statis). Ini menutup celah sewa jarak jauh — lihat bagian 12.
>
> **Update: Firmware Device Auth.** Endpoint firmware (`/poll`, `/report`, `/sync`) memerlukan header `X-Device-Token` — lihat bagian 5.0.

---

## 1. Cek Status Locker (dipanggil saat barcode di-scan)

**`GET /api/lockers/{locker_id}/status?token={token}`**

Dipanggil halaman web setelah berhasil scan QR (bukan lagi saat halaman pertama dibuka lewat link) untuk menentukan tampilan apa yang perlu ditunjukkan ke user.

`token` wajib dan berasal dari hasil scan QR barusan (lihat bagian 12). Backend validasi token ini masih berlaku untuk locker tersebut sebelum menjawab.

**Contoh response — token sudah kadaluarsa/tidak cocok (400):**

```json
{
  "status": "error",
  "code": "TOKEN_EXPIRED",
  "message": "QR sudah kedaluwarsa, silakan scan ulang"
}
```

**Contoh response — locker kosong (200):**

```json
{
  "locker_id": "locker_02",
  "status": "empty"
}
```

**Contoh response — locker sedang disewa (200):**

```json
{
  "locker_id": "locker_02",
  "status": "occupied"
}
```

**Contoh response — locker bermasalah/pintu tidak tertutup (200):**

```json
{
  "locker_id": "locker_02",
  "status": "needs_attention"
}
```

`status: "needs_attention"` membuat web menampilkan pesan bahwa locker sedang tidak bisa dipakai sementara, tanpa membuka form sewa baru.

---

## 2. Sewa Locker (Scan Pertama Kali — Locker Kosong)

**`POST /api/lockers/{locker_id}/rent`**

Dipanggil setelah user isi form nama & no HP di halaman hasil scan. **Tidak ada login/registrasi akun** — cukup data ini per sesi.

| Field   | Tipe   | Keterangan                                   |
| ------- | ------ | -------------------------------------------- |
| `nama`  | string | Nama penyewa                                 |
| `no_hp` | string | Nomor HP penyewa                             |
| `token` | string | Token dari hasil scan QR barusan (bagian 12) |

Backend akan:

1. Validasi `token` masih berlaku untuk locker ini (menutup celah sewa jarak jauh — lihat bagian 12)
2. Validasi locker masih `empty` (mencegah race condition — lihat bagian 7)
3. Generate `unique_code` acak (6-8 karakter alfanumerik)
4. Simpan sesi sewa baru dengan `started_at`
5. Antrikan perintah "unlock" untuk firmware locker ini (lihat bagian 5)

**Contoh response gagal — token kedaluwarsa (400):**

```json
{
  "status": "error",
  "code": "TOKEN_EXPIRED",
  "message": "QR sudah kedaluwarsa, silakan scan ulang"
}
```

**Contoh response sukses (200):**

```json
{
  "status": "ok",
  "rental_id": "rnt_2001",
  "unique_code": "A3F9K2",
  "started_at": "2026-09-16T10:00:00Z"
}
```

**PENTING:** `unique_code` hanya dikirim **1 kali** di response ini. Web wajib menampilkannya dengan jelas + tombol copy, dan mengingatkan user untuk menyimpannya sendiri — backend tidak menyimpan kode ini dalam bentuk plain text yang bisa ditampilkan ulang (lihat bagian 8).

**Contoh response gagal — locker sudah tidak kosong (409):**

```json
{
  "status": "error",
  "message": "Locker sudah terisi"
}
```

---

## 3. Ambil Barang / Buka Ulang (Scan Ulang — Locker Terisi)

**`POST /api/lockers/{locker_id}/access`**

Dipanggil setelah user (yang locker-nya sedang `occupied`) memasukkan kode uniknya di halaman hasil scan ulang.

| Field    | Tipe   | Keterangan                                            |
| -------- | ------ | ----------------------------------------------------- |
| `code`   | string | Kode unik yang dimasukkan user                        |
| `action` | string | `"continue"` (lanjut sewa) atau `"end"` (akhiri sewa) |

Backend memvalidasi `code` cocok dengan sesi aktif locker ini. Kalau cocok, antrikan perintah "unlock" ke firmware, dan simpan `action` untuk menentukan apa yang terjadi saat pintu terdeteksi tertutup lagi (lihat bagian 6).

**Contoh response sukses (200):**

```json
{
  "status": "ok",
  "action": "continue",
  "unlocked": true
}
```

**Contoh response gagal — kode salah (400):**

```json
{
  "status": "error",
  "message": "Kode tidak valid"
}
```

Pesan ini **sengaja sama** baik untuk kode salah ketik maupun kode yang memang bukan untuk locker ini — supaya tidak memberi petunjuk ke orang yang coba menebak kode locker lain (lihat bagian 8 soal rate limit).

**Contoh response gagal — terlalu banyak percobaan salah (429):**

```json
{
  "status": "error",
  "message": "Terlalu banyak percobaan, locker dikunci sementara"
}
```

---

## 4. Cek Status Sesi (Durasi Berjalan)

**`GET /api/rentals/{rental_id}/status`**

Dipanggil halaman web secara berkala (polling tiap 3 detik) untuk menampilkan durasi berjalan (naik terus, bukan countdown — mengikuti model parkir).

**Contoh response (200):**

```json
{
  "rental_status": "active",
  "locker_id": "locker_02",
  "started_at": "2026-09-16T10:00:00Z",
  "elapsed_seconds": 1080
}
```

**Contoh response — sesi sudah selesai (200):**

```json
{
  "rental_status": "completed",
  "locker_id": "locker_02",
  "started_at": "2026-09-16T10:00:00Z",
  "ended_at": "2026-09-16T10:18:00Z",
  "total_duration_seconds": 1080
}
```

---

## 5. Firmware Polling — Ambil Perintah (ESP32 → Backend)

### 5.0 Autentikasi Firmware (Wajib)

Semua endpoint firmware (`/poll`, `/report`, `/sync`) memerlukan header:

```
X-Device-Token: <authToken>
```

`authToken` disimpan di Firestore collection `controllers/{controller_id}` dan di-seed via `backend-express/seedController.js`. Setiap controller punya token unik.

**Response kalau header tidak ada (401):**

```json
{ "status": "error", "message": "MISSING_DEVICE_TOKEN" }
```

**Response kalau token tidak cocok (401):**

```json
{ "status": "error", "message": "INVALID_DEVICE_TOKEN" }
```

**Response kalau controller tidak terdaftar (404):**

```json
{ "status": "error", "message": "CONTROLLER_NOT_REGISTERED" }
```

### 5.1 Polling Biasa

**`GET /api/firmware/{locker_controller_id}/poll`**

Dipanggil **ESP32**, bukan sebaliknya. Setiap unit controller (menangani hingga 4 locker) memanggil endpoint ini secara berkala (**interval 2 detik**) untuk mengecek apakah ada perintah buka yang perlu dieksekusi.

Response juga membawa `qr_tokens` — token QR terbaru untuk tiap locker di unit ini, supaya firmware bisa merender ulang QR di layar TFT-nya (lihat bagian 12). Field ini selalu ada di setiap response poll, terlepas dari ada/tidaknya `commands`.

**Contoh response — ada perintah untuk locker index 2 (200):**

```json
{
  "commands": [{ "locker_index": 2, "action": "unlock", "pulse_hold": true }],
  "qr_tokens": {
    "0": "7c1e9a",
    "1": "b04f2d",
    "2": "9f3a1c",
    "3": "e21a88"
  }
}
```

`pulse_hold: true` artinya solenoid tetap energized (terbuka) sampai firmware mengirim event "closed" (bagian 6) — bukan pulsa waktu tetap, karena locker ini pakai sensor magnet untuk auto-lock, bukan timer.

**Contoh response — tidak ada perintah (200):**

```json
{
  "commands": [],
  "qr_tokens": {
    "0": "7c1e9a",
    "1": "b04f2d",
    "2": "9f3a1c",
    "3": "e21a88"
  }
}
```

---

## 6. Firmware Melaporkan Status Pintu (ESP32 → Backend)

**`POST /api/firmware/{locker_controller_id}/report`**

Dipanggil ESP32 setiap kali sensor magnet mendeteksi **perubahan status** pintu (dari terbuka ke tertutup, atau sebaliknya) — bukan polling rutin, cuma saat ada perubahan.

Memerlukan header `X-Device-Token` (lihat bagian 5.0).

| Field          | Tipe   | Keterangan                     |
| -------------- | ------ | ------------------------------ |
| `locker_index` | number | Index locker di unit ini (0-3) |
| `event`        | string | `"opened"` atau `"closed"`     |

Saat backend menerima `event: "closed"`:

- Kalau sesi sedang berstatus `pending_end` (user pilih "Ambil Barang & Akhiri Sewa" di bagian 3) → backend finalisasi sesi (`total_duration_seconds` dihitung, status jadi `completed`, locker kembali `empty`)
- Kalau tidak (sewa baru atau user pilih "Lanjut Sewa") → backend cukup update locker kembali `occupied` seperti biasa (terkunci lagi, sesi tetap jalan)

**Contoh response (200):**

```json
{ "status": "ok" }
```

---

## 6b. Firmware Sync — Gabungan Poll + Report (Rekomendasi)

**`POST /api/firmware/{locker_controller_id}/sync`**

Endpoint alternatif yang **menggabungkan `/poll` dan `/report` menjadi satu request**. ESP32 mengirim state pintu + solenoid setiap 2 detik, dan backend mendeteksi transisi pintu sendiri dengan cara membandingkan dengan state sebelumnya (disimpan di memori).

Memerlukan header `X-Device-Token` (lihat bagian 5.0).

**Keuntungan:** ESP32 hanya kirim 1 request per siklus, hemat bandwidth + TLS handshake.

**Request body:**

| Field                   | Tipe    | Keterangan                            |
| ----------------------- | ------- | ------------------------------------- |
| `lockers`               | array   | Array state per locker                |
| `lockers[].index`       | number  | Index locker (0-3)                    |
| `lockers[].door_open`   | boolean | `true` jika pintu sedang terbuka      |
| `lockers[].solenoid_on` | boolean | `true` jika solenoid sedang energized |

**Contoh request:**

```json
{
  "lockers": [
    { "index": 0, "door_open": false, "solenoid_on": false },
    { "index": 1, "door_open": true, "solenoid_on": true },
    { "index": 2, "door_open": false, "solenoid_on": false },
    { "index": 3, "door_open": false, "solenoid_on": false }
  ]
}
```

**Contoh response (200):**

```json
{
  "commands": [],
  "qr_tokens": {
    "0": "9f3a1c",
    "1": "7c1e9a",
    "2": "b04f2d",
    "3": "e21a88"
  }
}
```

**Logic backend:**

1. Backend menyimpan state pintu dari request sebelumnya per locker (in-memory).
2. Saat request baru masuk, backend bandingkan `door_open`:
   - `false → true` = pintu baru terbuka → log saja
   - `true → false` = pintu baru tertutup → jalankan logic `closed` (sama seperti `/report`)
3. Response berisi `commands` + `qr_tokens`, sama seperti `/poll`.

**Catatan:** Endpoint `/poll` dan `/report` lama **tetap berfungsi** untuk backward compatibility.

---

## 7. Mencegah Rebutan Locker yang Sama (Race Condition)

Kalau 2 device mengirim `POST /api/lockers/{locker_id}/rent` di detik yang nyaris sama:

- Backend memproses berdasarkan urutan diterima; permintaan pertama berhasil (locker langsung ditandai `occupied`)
- Permintaan kedua ditolak dengan:

```json
{
  "status": "error",
  "message": "Locker sudah terisi"
}
```

Status HTTP: **409 Conflict**.

> **Catatan:** Draft awal dokumen ini membedakan pesan untuk race condition ("Sedang dalam antrian, silakan coba lagi") dan kasus locker memang sudah terisi orang lain. Namun karena Firestore transaction tidak memberikan cara andal untuk membedakan kedua kasus tersebut, kedua-duanya dikembalikan dengan pesan yang sama: `"Locker sudah terisi"`. Pesan ini cukup jelas untuk user — mereka tahu locker tidak bisa dipakai.

---

## 8. Keamanan Kode Unik

- `unique_code` disimpan di database dalam bentuk **hash** (bukan plain text) — mirip prinsip penyimpanan password, supaya kalaupun database bocor, kode user tidak langsung ketahuan.
- **Rate limit percobaan kode salah**: maksimal 5x percobaan gagal per locker dalam 10 menit, setelah itu endpoint `/access` locker tersebut dikunci sementara (5 menit) sebelum bisa dicoba lagi. Selama lock, response adalah **429**.
- `unique_code` hanya ditampilkan **1 kali** di response `/rent` — tidak ada endpoint untuk "lihat ulang kode saya", karena itu sama saja membuka celah orang lain menebak/melihat kode orang lain.

---

## 9. Mitigasi Pintu Tidak Tertutup (Timeout)

Backend menjalankan job berkala yang mengecek: kalau sebuah locker berstatus "sedang dibuka" (menerima perintah unlock) tapi **belum ada event `"closed"` dalam 2 menit**, locker otomatis ditandai:

```json
{
  "locker_id": "locker_02",
  "status": "needs_attention",
  "unlocked_since": "2026-09-16T10:05:00Z"
}
```

Locker dengan status ini **tidak bisa disewa user baru** (lihat bagian 1) sampai petugas menyelesaikannya lewat dashboard (bagian 10). Begitu locker ditandai `needs_attention`, backend juga **mengirim push notification ke semua device petugas yang terdaftar** (via FCM).

---

## 10. Autentikasi & Endpoint Admin (App Petugas Keamanan & Kebersihan)

Bagian ini dikonsumsi oleh **app Flutter internal**, bukan halaman web publik.

### 10.1 Login

**`POST /api/auth/login`**

| Field      | Tipe   | Keterangan       |
| ---------- | ------ | ---------------- |
| `username` | string | Username petugas |
| `password` | string | Password         |

**Contoh response sukses (200):**

```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "role": "admin",
  "nama": "Admin Smart Locker"
}
```

`role` cuma dua kemungkinan: `"admin"` atau `"petugas"`.

**Contoh response gagal (401):**

```json
{ "status": "error", "message": "Username atau password salah" }
```

Akun petugas/admin dibuat manual lewat seed di Firestore (collection `petugas`), **tidak ada endpoint register**. Token JWT berlaku **7 hari**, tanpa refresh token.

### 10.2 Proteksi Endpoint dengan JWT

Endpoint admin berikut **wajib** menyertakan header:

```
Authorization: Bearer <token_dari_login>
```

- Endpoint **tanpa** header → 401 `MISSING_TOKEN`
- Endpoint dengan token invalid/expired → 401 `INVALID_TOKEN`
- Endpoint dengan token valid tapi role tidak sesuai → 403 `FORBIDDEN`

Endpoint yang diproteksi JWT:

- `GET /api/admin/lockers`
- `POST /api/admin/lockers/{locker_id}/resolve`
- `GET /api/admin/reports/rentals` (khusus role `admin`)

### 10.3 Dashboard Status Locker

**`GET /api/admin/lockers`** — butuh JWT

**Contoh response (200):**

```json
{
  "lockers": [
    { "locker_id": "locker_01", "status": "empty" },
    {
      "locker_id": "locker_02",
      "status": "needs_attention",
      "unlocked_since": "2026-09-16T10:05:00Z"
    },
    { "locker_id": "locker_03", "status": "occupied", "elapsed_seconds": 620 },
    { "locker_id": "locker_04", "status": "empty" }
  ]
}
```

### 10.4 Resolve Locker Bermasalah

**`POST /api/admin/lockers/{locker_id}/resolve`** — butuh JWT

Dipanggil petugas lewat app setelah mengecek & menutup manual locker yang berstatus `needs_attention`, mengembalikan status locker ke `empty`.

**Contoh response sukses (200):**

```json
{
  "status": "ok",
  "locker_id": "locker_02",
  "new_status": "empty"
}
```

**Response gagal:**

- `404 LOCKER_NOT_FOUND` — locker tidak ada
- `409 NOT_NEEDS_ATTENTION` — locker sudah tidak dalam status `needs_attention`

### 10.5 Register Device Notifikasi

**`POST /api/admin/register-device`** — **tanpa JWT** (dipanggil saat first-time setup)

| Field        | Tipe   | Keterangan                                            |
| ------------ | ------ | ----------------------------------------------------- |
| `fcm_token`  | string | Token push notification dari Firebase Cloud Messaging |
| `petugas_id` | string | Identitas petugas (nama/NIP)                          |

**Contoh response (200):**

```json
{ "status": "ok" }
```

### 10.6 Laporan Sesi Sewa

**`GET /api/admin/reports/rentals`** — butuh JWT, **khusus role `admin`**

**Contoh response (200):**

```json
{
  "stats": {
    "total_rentals": 9,
    "avg_duration_seconds": 593,
    "busiest_locker_id": "locker_01"
  },
  "rentals": [
    {
      "rental_id": "rnt_2001",
      "locker_id": "locker_01",
      "nama": "Budi Santoso",
      "no_hp": "0812****89",
      "started_at": "2026-09-23T05:00:00Z",
      "ended_at": "2026-09-23T05:18:00Z",
      "total_duration_seconds": 1080,
      "status": "completed"
    }
  ]
}
```

Catatan:

- `no_hp` di-mask sebagian (`0812****89`) untuk privasi
- Sesi yang masih aktif: `ended_at` dan `total_duration_seconds` bernilai `null`
- Belum ada filter tanggal — semua riwayat ditampilkan

### 10.7 Push Notification (Backend → App)

Begitu backend menandai sebuah locker `needs_attention` (lihat bagian 9), backend langsung mengirim push notification lewat FCM ke semua token petugas yang terdaftar di `petugas_devices`, dengan payload kira-kira:

```json
{
  "title": "Locker Perlu Perhatian",
  "body": "Locker_02 - pintu belum tertutup sejak 2 menit lalu",
  "data": { "locker_id": "locker_02" }
}
```

---

## 11. Kode Status HTTP yang Dipakai

| Kode | Arti                                                        |
| ---- | ----------------------------------------------------------- |
| 200  | Request berhasil diproses                                   |
| 400  | Parameter tidak valid / kode unik salah / token QR expired  |
| 401  | Tidak ada token JWT, atau token JWT/device invalid/expired  |
| 403  | Token JWT valid tapi role tidak sesuai                      |
| 404  | Resource tidak ditemukan (locker, rental, controller)       |
| 409  | Konflik — locker sudah terisi, atau state tidak sesuai      |
| 429  | Terlalu banyak percobaan kode salah, coba lagi nanti        |
| 500  | Error di sisi backend/firmware (mis. relay gagal merespons) |

---

## 12. QR Dinamis & Validasi Token

**Kenapa perlu:** kalau QR/link statis, siapa pun yang pernah lihat/menyimpan link-nya bisa buka & "sewa" locker dari jarak jauh — solenoid tetap benar-benar terbuka meski tidak ada orang di depan locker, dan karena tidak ada yang membuka/menutup pintu, locker itu akan timeout jadi `needs_attention` (bagian 9) sia-sia. Kalau pola link ke-4 locker diketahui, ini bisa dipakai melumpuhkan seluruh sistem dari jarak jauh.

**Cara kerja:**

1. Selama locker berstatus `empty`, backend generate token acak pendek per locker dan **merotasinya tiap 5 detik** (in-memory, tanpa write ke Firestore — untuk hemat quota)
2. Begitu locker berpindah ke `occupied` (ada yang berhasil sewa), backend **membekukan token itu** — tidak dirotasi lagi selama sesi berjalan, supaya QR yang ditampilkan tetap sama saat user yang sama scan ulang untuk ambil barang (bagian 3). Token kembali dirotasi begitu sesi selesai dan locker balik `empty`
3. Token (baik yang sedang rotasi maupun yang dibekukan) dikirim ke firmware lewat `qr_tokens` di response polling (bagian 5 atau 6b) — tidak perlu koneksi baru, menumpang mekanisme polling yang sudah ada
4. Firmware merender token jadi QR di layar TFT IPS 1.3" yang ditempel di badan locker (`hardware/RAB.xlsx` item 1.12) — ganti stiker cetak statis
5. Isi QR: string pendek `{locker_id}.{token}`, contoh: `locker_02.9f3a1c`
6. Web (halaman awal, bukan hasil buka link) langsung membuka kamera & scan QR ini di dalam halaman itu sendiri (pakai library scan QR di browser)
7. Hasil scan (`locker_id` + `token`) dikirim ke `GET /status` dan `POST /rent` (lihat bagian 1 & 2) — backend menolak kalau token sudah tidak berlaku untuk locker tersebut

**Masa berlaku token — dipisah dari interval tampilan:**

- **Interval tampilan di layar locker:** 5 detik (locker `empty`) — ini yang membuat "curi lihat dari jauh" sempit jendelanya
- **Masa berlaku token di sisi backend (untuk validasi `/status` & `/rent`): 60 detik** sejak token itu di-generate — supaya user yang baru saja scan tetap punya waktu wajar mengisi form nama & no HP, walau tampilan di layar locker sudah berganti beberapa detik berikutnya. Backend menyimpan histori singkat token per locker (bukan cuma token yang sedang tampil) supaya validasi 60 detik ini bisa jalan.
- Untuk locker `occupied`, tidak relevan — token sudah dibekukan sampai sesi selesai.

**Konsekuensi:** endpoint `GET /status` dan `POST /rent` sekarang **mewajibkan** `token` yang valid; endpoint `POST /access` (ambil barang) tetap memakai `unique_code` seperti sebelumnya dan tidak diubah, karena kode unik itu sendiri sudah jadi bukti sah kepemilikan sesi.

---

## 13. Catatan Implementasi Backend

Beberapa catatan penting untuk implementasi yang sudah berjalan di production:

### 13.1 Token QR — In-Memory

Karena quota Firestore free tier terbatas (20.000 writes/hari), **token QR tidak disimpan di Firestore**. Sebaliknya:

- Token di-generate & dirotasi **di RAM backend** (`tokenStoreService.js`)
- Rotasi tiap 5 detik via scheduler
- Saat backend restart, token store reload dari Firestore (baca sekali), lalu rotasi jalan lagi
- Kalau Firestore quota habis, fallback: pakai daftar locker default dengan status `empty`

**Konsekuensi:** kalau backend restart, token lama hilang. Firmware akan dapat token baru di poll berikutnya. User yang sedang scan mungkin harus scan ulang — tidak masalah untuk prototipe.

### 13.2 Device Auth Token — Cache 5 Menit

`authToken` per controller di-cache di memori (5 menit) supaya tidak read Firestore tiap request. Kalau token di Firestore diubah, tunggu max 5 menit atau restart backend.

### 13.3 Scheduler Jobs

Backend menjalankan beberapa job berkala:

- **Rotasi token QR** — tiap 5 detik
- **Timeout monitor** — tiap 30 detik, cek locker `occupied` yang pintunya belum tertutup > 2 menit

---

## Keputusan Final Tim

- [x] Tidak ada akun permanen — cukup nama & no HP per sesi
- [x] Kode unik ditampilkan 1x, disimpan sendiri oleh user (dengan tombol copy)
- [x] QR dinamis (bukan stiker statis) — token dirotasi tiap 5 detik saat locker kosong, dibekukan saat occupied, ditampilkan lewat layar TFT di locker, di-scan langsung di dalam web (bagian 12)
- [x] Masa berlaku token QR untuk validasi form sewa: 60 detik (terpisah dari interval tampilan 5 detik)
- [x] Arah komunikasi firmware: ESP32 polling ke backend (bukan backend memanggil IP ESP32), karena backend di-hosting di internet
- [x] Pilihan "Buka & Lanjut Sewa" vs "Ambil Barang & Akhiri Sewa" saat kode unik dimasukkan
- [x] Timeout pintu tidak tertutup: 2 menit, lalu locker ditandai `needs_attention`
- [x] Dashboard status locker untuk Petugas Keamanan & Kebersihan, dibangun sebagai **app Flutter (Android)** — dipilih karena butuh push notification, bukan web
- [x] Sisi pelanggan tetap sepenuhnya web (tanpa app, tanpa akun)
- [x] Autentikasi petugas/admin pakai **JWT** (expire 7 hari, tanpa refresh). Akun di-seed manual di Firestore, tidak ada endpoint register.
- [x] Rate limit percobaan kode salah: maksimal 5x per 10 menit, lock 5 menit (HTTP 429)
- [x] Push notification via FCM saat locker `needs_attention`
- [x] Device auth token untuk endpoint firmware (`/poll`, `/report`, `/sync`)
- [x] Token QR disimpan **in-memory** untuk hemat Firestore quota
- [x] Endpoint `/sync` sebagai alternatif `/poll` + `/report` (1 request gabungan)
- [ ] Interval polling firmware final (draft: 2 detik) — **perlu dikonfirmasi tim saat uji coba nyata**
- [ ] Mekanisme pembayaran (rencana masa depan, di luar sesi diakhiri) — **belum didesain, di luar scope prototipe kampus**
