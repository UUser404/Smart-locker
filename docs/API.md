# Kontrak API — Smart Locker

Dokumen ini adalah **kontrak resmi** antara backend server, firmware ESP32 (kontrol solenoid), dan app Android Flutter (dipakai user untuk daftar, pesan, dan scan barcode).

> ⚠️ Kalau ada perubahan endpoint/format, update dokumen ini DULU sebelum ubah kode, lalu kabari bagian lain. Ini mencegah app, backend, dan firmware saling nggak sinkron.

Base URL backend (contoh): `http://<ip-server-backend>/api`
Base URL tiap unit firmware locker (LAN lokal): `http://<ip-esp32-locker>`

---

## 1. Registrasi & Login User

**`POST /api/register`**

| Field      | Tipe   | Keterangan                |
| ---------- | ------ | ------------------------- |
| `nama`     | string | Nama user                 |
| `email`    | string | Email user                |
| `password` | string | Password (hash di server) |

**`POST /api/login`**

**Contoh response sukses (200):**

```json
{
  "status": "ok",
  "token": "eyJhbGciOi...",
  "user_id": "usr_001"
}
```

---

## 2. Pesan Locker (Mulai Sesi Sewa)

**`POST /api/rentals`**

Membuat sesi sewa baru untuk user yang sudah login. **Tidak ada input durasi di sini** — modelnya seperti parkir: user tidak menentukan lama pakai di muka, sistem hanya mencatat kapan sesi dimulai. Sesi ini awalnya berstatus **`pending_scan`** — belum terikat ke locker fisik mana pun sampai user berhasil scan barcode.

| Field     | Tipe   | Keterangan               |
| --------- | ------ | ------------------------ |
| `user_id` | string | Diambil dari token login |

**Contoh response sukses (200):**

```json
{
  "status": "ok",
  "rental_id": "rnt_1001",
  "rental_status": "pending_scan"
}
```

---

## 3. Scan Barcode & Aktivasi Locker

**`POST /api/rentals/{rental_id}/activate`**

Dipanggil app setelah kamera HP berhasil membaca barcode di salah satu locker fisik. Backend memvalidasi:

- Barcode dikenali sebagai locker yang valid
- Locker tersebut sedang **kosong** (tidak dipakai sesi sewa lain)
- `rental_id` masih berstatus `pending_scan` dan belum kedaluwarsa

| Field     | Tipe   | Keterangan                          |
| --------- | ------ | ----------------------------------- |
| `barcode` | string | Hasil decode barcode dari kamera HP |

**Contoh response sukses (200):**

```json
{
  "status": "ok",
  "rental_status": "active",
  "locker_id": "locker_02",
  "unlocked": true,
  "started_at": "2026-09-14T15:00:00Z"
}
```

**Contoh response gagal — locker sedang dipakai sesi lain (409):**

```json
{
  "status": "error",
  "message": "Locker sedang digunakan",
  "locker_id": "locker_02"
}
```

**Contoh response gagal — barcode tidak dikenali (400):**

```json
{
  "status": "error",
  "message": "Barcode tidak valid"
}
```

Setelah validasi sukses, backend meneruskan perintah buka ke firmware locker terkait (lihat bagian 5).

---

## 4. Akhiri Sesi Sewa (Ambil Barang / Selesai Pakai)

**`POST /api/rentals/{rental_id}/end`**

Dipanggil user lewat app saat selesai pakai dan mau ambil barang. **Seperti tiket parkir**: total durasi pakai baru dihitung di sini, dari `started_at` sampai waktu endpoint ini dipanggil — bukan dari durasi yang ditentukan di awal.

**Contoh response (200):**

```json
{
  "status": "ok",
  "rental_status": "completed",
  "locker_id": "locker_02",
  "unlocked": true,
  "started_at": "2026-09-14T15:00:00Z",
  "ended_at": "2026-09-14T16:12:00Z",
  "total_duration_seconds": 4320
}
```

Backend mengirim sinyal buka ke firmware (supaya user bisa ambil barang), lalu menandai locker kembali **kosong** setelah durasi buka singkat berakhir.

---

## 5. Perintah Buka ke Firmware (Backend → ESP32)

**`GET /unlock?locker={id}&pulse_ms={durasi}`**

Dipanggil **backend**, bukan app, langsung ke IP ESP32 locker yang bersangkutan (asumsi backend & ESP32 satu jaringan lokal). Firmware menyalakan relay solenoid selama `pulse_ms` milidetik lalu otomatis mengunci kembali (solenoid fail-secure).

| Parameter  | Tipe   | Keterangan                        |
| ---------- | ------ | --------------------------------- |
| `locker`   | number | Index locker di unit ini (0-3)    |
| `pulse_ms` | number | Lama solenoid terbuka (mis. 4000) |

**Contoh response (200):**

```json
{
  "status": "ok",
  "locker": 2,
  "unlocked_for_ms": 4000
}
```

---

## 6. Cek Status Locker & Sesi

**`GET /api/rentals/{rental_id}/status`**

Dipanggil app secara berkala (polling) untuk menampilkan **durasi berjalan** (bukan countdown, karena tidak ada durasi tetap di awal — mirip tampilan tiket parkir yang terus menghitung naik).

**Interval polling: 3 detik**.

**Contoh response (200):**

```json
{
  "rental_status": "active",
  "locker_id": "locker_02",
  "started_at": "2026-09-14T15:00:00Z",
  "elapsed_seconds": 1080
}
```

**`GET /api/lockers`**

Dipanggil app saat user mau tahu berapa locker yang masih kosong sebelum scan (opsional, untuk info awal).

```json
{
  "lockers": [
    { "locker_id": "locker_01", "status": "empty" },
    { "locker_id": "locker_02", "status": "occupied" },
    { "locker_id": "locker_03", "status": "empty" },
    { "locker_id": "locker_04", "status": "empty" }
  ]
}
```

---

## 7. Kode Status HTTP yang Dipakai

| Kode | Arti                                                        |
| ---- | ----------------------------------------------------------- |
| 200  | Request berhasil diproses                                   |
| 400  | Parameter tidak valid (mis. barcode tidak dikenali)         |
| 401  | Token login tidak valid/kadaluwarsa                         |
| 409  | Konflik — locker sedang dipakai sesi sewa lain              |
| 500  | Error di sisi backend/firmware (mis. relay gagal merespons) |

---

## 8. Catatan Implementasi

- Backend adalah **single source of truth** untuk status locker (kosong/disewa) — firmware tidak menyimpan status sewa, hanya mengeksekusi perintah buka dari backend.
- Response selalu JSON.
- Solenoid pakai skema **fail-secure**: default terkunci, hanya terbuka selama `pulse_ms` saat menerima perintah, lalu mengunci sendiri. Ini mencegah locker tetap terbuka kalau ESP32/koneksi bermasalah.
- CORS: **app Flutter (native Android) tidak terkena CORS** karena bukan request dari browser — hanya relevan kalau nanti ada dashboard web tambahan (mis. panel admin) yang mengakses backend dari browser.
- App user dibangun dengan **Flutter (Android)**, memakai package HTTP (`http`/`dio`) untuk komunikasi ke backend dan package scanner kamera (mis. `mobile_scanner`) untuk baca barcode.

---

## Keputusan Final Tim

- [ ] Durasi pulse solenoid saat buka (draft: 4 detik) — **perlu dikonfirmasi tim**
- [ ] Apakah ada batas maksimum lama sesi aktif (mis. seperti tarif inap/hilang tiket di parkir), atau sesi bisa berjalan tanpa batas sampai user sendiri mengakhiri — **perlu didiskusikan**
- [ ] Format & isi barcode tiap locker (ID polos vs terenkripsi/signed) — **perlu didiskusikan** supaya barcode tidak mudah dipalsukan
- [x] Jumlah unit locker prototipe: 4
- [x] Barcode discan lewat kamera HP (bukan scanner fisik terpisah)
- [x] Mekanisme kunci pakai solenoid door lock dikontrol microcontroller
- [x] Model sesi sewa seperti parkir: tidak ada durasi ditentukan di awal, total durasi dihitung dari waktu mulai (scan-in) sampai selesai (akhiri sesi)
- [x] App user dibangun dengan **Flutter (Android)**
