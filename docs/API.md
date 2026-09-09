# Kontrak API — ESP32 Smart Dispenser

Dokumen ini adalah **kontrak resmi** antara firmware ESP32 (dikerjakan tim Firmware) dan app Flutter (dikerjakan tim App). Endpoint yang sama juga dipakai oleh halaman captive portal (web UI).

> ⚠️ Kalau ada perubahan endpoint/format, update dokumen ini DULU sebelum ubah kode, lalu kabari tim lain. Ini mencegah app dan firmware saling nggak sinkron.

Base URL saat device terhubung ke WiFi ESP32 (mode AP): `http://192.168.4.1`

---

## 1. Pilih & Tuang Rasa (Start)

**`GET /pour?flavor={id}`**

Menyalakan pompa untuk rasa tertentu. Kalau ada pompa lain yang masih aktif, request ini akan **ditolak** (lihat kode error di bawah) — mencegah dua rasa tercampur atau konflik multi-user.

| Parameter | Tipe   | Keterangan                                                          |
| --------- | ------ | ------------------------------------------------------------------- |
| `flavor`  | string | `"milk"`, `"coffee"`, atau `"tea"` (sesuaikan dengan id rasa final) |

**Contoh response sukses (200):**

```json
{
  "status": "ok",
  "active_flavor": "milk",
  "pouring": true
}
```

**Contoh response gagal — pompa lain sedang aktif (409):**

```json
{
  "status": "error",
  "message": "Pump busy",
  "active_flavor": "coffee"
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

## 3. Hold-to-Pour (opsional, kalau dipisah dari /pour)

Kalau tim Firmware & App sepakat pakai mekanisme terpisah untuk hold-to-pour (tekan-tahan) vs toggle Start/Stop:

- **`POST /hold/start?flavor={id}`** — dipanggil saat user mulai menekan
- **`POST /hold/end`** — dipanggil saat user melepas tekanan

> Catatan: kalau koneksi app terputus saat hold-to-pour aktif, firmware sebaiknya punya **timeout otomatis** (mis. auto-stop kalau tidak ada ping/keep-alive dalam X detik) supaya pompa tidak menyala terus tanpa kontrol.

---

## 4. Cek Status

**`GET /status`**

Dipanggil app secara berkala (polling) untuk sinkron dengan status terbaru — penting kalau ada tamu lain yang kontrol lewat web di saat bersamaan.

**Contoh response (200):**

```json
{
  "active_flavor": "milk",
  "pouring": true,
  "flavors_available": ["milk", "coffee", "tea"]
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

## Belum Diputuskan (isi tim setelah diskusi)

- [ ] Finalisasi nama/id rasa (`milk`/`coffee`/`tea` atau yang lain)
- [ ] Apakah hold-to-pour pakai endpoint terpisah atau cukup `/pour` + `/stop`
- [ ] Interval polling `/status` yang ideal dari sisi app (disarankan mulai dari 1-2 detik)
- [ ] Mekanisme timeout otomatis kalau koneksi putus saat pompa aktif
