# Kontrak API — Smart Locker

Dokumen ini adalah **kontrak resmi** antara backend server, firmware ESP32 (kontrol solenoid & sensor magnet), dan web (dipakai user lewat scan barcode, dan petugas lewat dashboard).

> ⚠️ Kalau ada perubahan endpoint/format, update dokumen ini DULU sebelum ubah kode, lalu kabari bagian lain. Ini mencegah web, backend, dan firmware saling nggak sinkron.

Base URL backend: `https://<domain-backend>/api` (hosting internet, bukan LAN lokal)

> Catatan arsitektur: karena backend di-hosting di internet sementara ESP32 ada di jaringan lokal kampus, **arah komunikasi firmware terbalik dari desain awal** — ESP32 yang polling ke backend secara berkala, bukan backend yang memanggil IP ESP32 langsung (lihat bagian 5 & 6).

---

## 1. Cek Status Locker (dipanggil saat barcode di-scan)

**`GET /api/lockers/{locker_id}/status`**

Dipanggil halaman web pertama kali dibuka (hasil scan barcode) untuk menentukan tampilan apa yang perlu ditunjukkan ke user.

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

| Field   | Tipe   | Keterangan       |
| ------- | ------ | ---------------- |
| `nama`  | string | Nama penyewa     |
| `no_hp` | string | Nomor HP penyewa |

Backend akan:

1. Validasi locker masih `empty` (mencegah race condition — lihat bagian 7)
2. Generate `unique_code` acak (6-8 karakter alfanumerik)
3. Simpan sesi sewa baru dengan `started_at`
4. Antrikan perintah "unlock" untuk firmware locker ini (lihat bagian 5)

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

**`GET /api/firmware/{locker_controller_id}/poll`**

Dipanggil **ESP32**, bukan sebaliknya. Setiap unit controller (menangani hingga 4 locker) memanggil endpoint ini secara berkala (**interval 2 detik**) untuk mengecek apakah ada perintah buka yang perlu dieksekusi.

**Contoh response — ada perintah untuk locker index 2 (200):**

```json
{
  "commands": [{ "locker_index": 2, "action": "unlock", "pulse_hold": true }]
}
```

`pulse_hold: true` artinya solenoid tetap energized (terbuka) sampai firmware mengirim event "closed" (bagian 6) — bukan pulsa waktu tetap, karena locker ini pakai sensor magnet untuk auto-lock, bukan timer.

**Contoh response — tidak ada perintah (200):**

```json
{
  "commands": []
}
```

---

## 6. Firmware Melaporkan Status Pintu (ESP32 → Backend)

**`POST /api/firmware/{locker_controller_id}/report`**

Dipanggil ESP32 setiap kali sensor magnet mendeteksi **perubahan status** pintu (dari terbuka ke tertutup, atau sebaliknya) — bukan polling rutin, cuma saat ada perubahan.

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

## 7. Mencegah Rebutan Locker yang Sama (Race Condition)

Kalau 2 device mengirim `POST /api/lockers/{locker_id}/rent` di detik yang nyaris sama:

- Backend memproses berdasarkan urutan diterima; permintaan pertama berhasil (locker langsung ditandai `occupied`)
- Permintaan kedua akan menerima response konflik:

```json
{
  "status": "error",
  "message": "Sedang dalam antrian, silakan coba lagi",
  "code": "CONCURRENT_REQUEST"
}
```

Pesan ini **berbeda** dari pesan "Locker sudah terisi" di bagian 2 — supaya user tahu ini cuma soal waktu (boleh coba scan ulang beberapa detik lagi), bukan karena locker memang sudah keisi orang lain duluan.

---

## 8. Keamanan Kode Unik

- `unique_code` disimpan di database dalam bentuk **hash** (bukan plain text) — mirip prinsip penyimpanan password, supaya kalaupun database bocor, kode user tidak langsung ketahuan.
- **Rate limit percobaan kode salah**: maksimal 5x percobaan gagal per locker dalam 10 menit, setelah itu endpoint `/access` locker tersebut dikunci sementara (mis. 5 menit) sebelum bisa dicoba lagi.
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

Locker dengan status ini **tidak bisa disewa user baru** (lihat bagian 1) sampai petugas menyelesaikannya lewat dashboard (bagian 10).

---

## 10. App Petugas Keamanan & Kebersihan (Flutter)

Bagian ini dikonsumsi oleh **app Flutter internal**, bukan halaman web publik.

**`GET /api/admin/lockers`**

Menampilkan status semua locker untuk dashboard di app petugas.

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

**`POST /api/admin/lockers/{locker_id}/resolve`**

Dipanggil petugas lewat app setelah mengecek & menutup manual locker yang berstatus `needs_attention`, mengembalikan status locker ke `empty`.

**Contoh response (200):**

```json
{
  "status": "ok",
  "locker_id": "locker_02",
  "new_status": "empty"
}
```

**`POST /api/admin/register-device`**

Dipanggil app Flutter sekali saat pertama kali dibuka/login, untuk mendaftarkan token push notification (FCM) milik HP petugas.

| Field        | Tipe   | Keterangan                                            |
| ------------ | ------ | ----------------------------------------------------- |
| `fcm_token`  | string | Token push notification dari Firebase Cloud Messaging |
| `petugas_id` | string | Identitas petugas (nama/NIP, sesuai kebutuhan)        |

**Contoh response (200):**

```json
{ "status": "ok" }
```

**Push Notification — dikirim backend ke app (bukan dipanggil app):**

Begitu backend menandai sebuah locker `needs_attention` (lihat bagian 9), backend langsung mengirim push notification lewat FCM ke semua token petugas yang terdaftar, dengan payload kira-kira:

```json
{
  "title": "Locker Perlu Perhatian",
  "body": "Locker_02 - pintu belum tertutup sejak 2 menit lalu",
  "data": { "locker_id": "locker_02" }
}
```

> Catatan: app ini untuk prototipe belum pakai autentikasi login penuh (asumsi hanya dipakai petugas terpercaya, instalasi app terbatas ke HP mereka) — kalau dikembangkan lebih lanjut, perlu ditambah login/PIN staf.

---

## 11. Kode Status HTTP yang Dipakai

| Kode | Arti                                                         |
| ---- | ------------------------------------------------------------ |
| 200  | Request berhasil diproses                                    |
| 400  | Parameter tidak valid / kode unik salah                      |
| 409  | Konflik — locker sudah terisi, atau race condition sementara |
| 429  | Terlalu banyak percobaan kode salah, coba lagi nanti         |
| 500  | Error di sisi backend/firmware (mis. relay gagal merespons)  |

---

## Keputusan Final Tim

- [x] Tidak ada akun permanen — cukup nama & no HP per sesi
- [x] Kode unik ditampilkan 1x, disimpan sendiri oleh user (dengan tombol copy)
- [x] Arah komunikasi firmware: ESP32 polling ke backend (bukan backend memanggil IP ESP32), karena backend di-hosting di internet
- [x] Pilihan "Buka & Lanjut Sewa" vs "Ambil Barang & Akhiri Sewa" saat kode unik dimasukkan
- [x] Timeout pintu tidak tertutup: 2 menit, lalu locker ditandai `needs_attention`
- [x] Dashboard status locker untuk Petugas Keamanan & Kebersihan, dibangun sebagai **app Flutter (Android)** — dipilih karena butuh push notification, bukan web
- [x] Sisi pelanggan tetap sepenuhnya web (tanpa app, tanpa akun)
- [ ] Interval polling firmware final (draft: 2 detik) — **perlu dikonfirmasi tim saat uji coba nyata**
- [ ] Mekanisme pembayaran (rencana masa depan, di luar sesi diakhiri) — **belum didesain, di luar scope prototipe kampus**
