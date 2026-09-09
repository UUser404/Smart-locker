# Kontrak API — ESP32 Smart Dispenser

Dokumen ini adalah **kontrak resmi** antara firmware ESP32 (dikerjakan tim Firmware) dan app Flutter (dikerjakan tim App). Endpoint yang sama juga dipakai oleh halaman captive portal (web UI).

> ⚠️ Kalau ada perubahan endpoint/format, update dokumen ini DULU sebelum ubah kode, lalu kabari tim lain. Ini mencegah app dan firmware saling nggak sinkron.

Base URL saat device terhubung ke WiFi ESP32 (mode AP): `http://192.168.4.1`

---

## 1. Pilih & Tuang Rasa (Start)

**`GET /pour?flavor={id}`**

Menyalakan pompa untuk rasa tertentu. Kalau ada pompa lain yang masih aktif, request ini akan **ditolak** (lihat kode error di bawah) — mencegah dua rasa tercampur atau konflik multi-user.

| Parameter | Tipe   | Keterangan                       |
| --------- | ------ | -------------------------------- |
| `flavor`  | string | `"susu"`, `"kopi"`, atau `"teh"` |

**Contoh response sukses (200):**

```json
{
  "status": "ok",
  "active_flavor": "susu",
  "pouring": true
}
```

**Contoh response gagal — pompa lain sedang aktif (409):**

```json
{
  "status": "error",
  "message": "Pump busy",
  "active_flavor": "kopi"
}
```

---

## 2. Stop Menuang

**`GET /stop`**

Mematikan pompa yang sedang aktif, siapa pun yang menyalakannya (web atau app).

**Contoh response (200):**

```json
{
  "status": "ok",
  "active_flavor": null,
  "pouring": false
}
```

---

## 3. Hold-to-Pour (endpoint terpisah dari toggle Start/Stop)

**Sudah difinalisasi:** hold-to-pour pakai endpoint sendiri, terpisah dari `/pour` (toggle Start/Stop). Firmware tetap menjaga aturan **hanya 1 pompa aktif dalam satu waktu** untuk kedua mekanisme ini — kalau pompa lain (dari toggle Start/Stop maupun hold-to-pour rasa lain) sedang aktif, request akan ditolak dengan `409` seperti pada endpoint `/pour`.

- **`POST /hold/start?flavor={id}`** — dipanggil saat user mulai menekan-tahan
- **`POST /hold/end`** — dipanggil saat user melepas tekanan

**Contoh response sukses `/hold/start` (200):**

```json
{
  "status": "ok",
  "active_flavor": "teh",
  "pouring": true,
  "mode": "hold"
}
```

**Contoh response gagal — pompa lain aktif (409):**

```json
{
  "status": "error",
  "message": "Pump busy",
  "active_flavor": "susu"
}
```

### Penanganan koneksi terputus saat hold-to-pour aktif

**Sudah difinalisasi:** kalau koneksi terputus (device offline / app force-close / WiFi putus) saat hold-to-pour sedang berjalan, firmware **otomatis menghentikan pompa** dan menganggap proses menuang selesai — bukan menunggu keep-alive/ping dulu. Ini prioritas keamanan: lebih baik pompa berhenti lebih awal daripada menyala tanpa kontrol.

Implementasi disarankan: firmware set timeout pendek (mis. 2-3 detik tanpa request `/hold/start` atau keep-alive lanjutan) yang men-trigger auto-stop.

---

## 4. Cek Status

**`GET /status`**

Dipanggil app secara berkala (polling) untuk sinkron dengan status terbaru — penting kalau ada tamu lain yang kontrol lewat web di saat bersamaan.

**Interval polling sudah difinalisasi: 1,5 detik** dari sisi app.

**Contoh response (200):**

```json
{
  "active_flavor": "susu",
  "pouring": true,
  "flavors_available": ["susu", "kopi", "teh"]
}
```

---

## 5. Kode Status HTTP yang Dipakai

| Kode | Arti                                                         |
| ---- | ------------------------------------------------------------ |
| 200  | Request berhasil diproses                                    |
| 409  | Konflik — ada pompa lain sedang aktif (lock multi-user)      |
| 400  | Parameter tidak valid (mis. `flavor` tidak dikenal)          |
| 500  | Error di sisi firmware/hardware (mis. relay gagal merespons) |

---

## 6. Catatan Implementasi

- Semua endpoint pakai `GET` untuk simplicity (kecuali hold-to-pour, opsional pakai `POST`) — samakan gaya antara web JS dan Flutter `http` package.
- Response selalu JSON, supaya gampang di-parse baik oleh JS di web maupun `dart:convert` di app.
- CORS: kalau app Flutter mengakses endpoint ini sebagai request lintas origin, pastikan firmware mengirim header `Access-Control-Allow-Origin: *` supaya tidak diblokir.

---

## Keputusan Final Tim

- [x] Id rasa: `susu`, `kopi`, `teh`
- [x] Hold-to-pour pakai endpoint terpisah (`/hold/start`, `/hold/end`), tetap tunduk pada aturan 1-pompa-aktif
- [x] Interval polling `/status` dari app: **1,5 detik**
- [x] Kalau koneksi terputus saat pompa aktif: pompa **auto-stop**, proses menuang dianggap selesai (bukan nunggu keep-alive)
- [x] Nilai timeout pasti untuk auto-stop di firmware adalah 3 detik
