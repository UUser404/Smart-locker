# Smart Locker Firmware (ESP32)

Firmware ESP32 untuk sistem Smart Locker IoT. Berkomunikasi dengan backend Express di Render via HTTPS, mengeksekusi perintah unlock, melaporkan state pintu, dan menampilkan QR dinamis di layar TFT.

> **Update terakhir: 15 Oktober 2026** — bench test TFT di hardware asli, plus revisi `main.cpp`, `door_sensor.cpp`, dan `tft_render.cpp`.
> Bagian bertanda 🔧 atau ⏳ **belum diuji di hardware**.

## Status Saat Ini

| Komponen         | Status                         | Keterangan                                                                                                             |
| ---------------- | ------------------------------ | ---------------------------------------------------------------------------------------------------------------------- |
| `wifi_client`    | ✅ Tested                      | Connect + reconnect                                                                                                    |
| `backend_poller` | ✅ Tested                      | `POST /sync` tiap 2 detik, parse JSON                                                                                  |
| `event_reporter` | ⚪ Tidak dipakai di alur utama | State pintu dikirim lewat `/sync`. `report_door_event()` (`POST /report`) dipertahankan untuk kompatibilitas           |
| `lock_control`   | 🔧 Compile OK                  | Belum diuji dengan relay/solenoid fisik                                                                                |
| `door_sensor`    | 🔧 Direvisi                    | Debounce diganti (lihat bawah). Belum diuji ulang dengan limit switch — pengujian ditunda                              |
| `tft_render`     | 🔧 Sebagian                    | Layar merespons dan teks tampil di hardware asli. **QR belum tampil** (penyebab belum diketahui)                       |
| `main.cpp`       | 🔧 Direvisi                    | Auto-lock + latch pintu + redraw QR hanya saat token berubah. Baru env `bench` yang pernah di-build; belum diuji penuh |

## Hasil Uji Hardware (15 Okt 2026)

| Tes                                                            | Env        | Hasil                                                                                                                                                                     |
| -------------------------------------------------------------- | ---------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Build env `bench`                                              | `bench`    | ✅ Sukses setelah paket framework Arduino-ESP32 diunduh ulang (lihat Troubleshooting)                                                                                     |
| Tes mentah TFT, tanpa library (`tft_raw_test.cpp`)             | `rawtft`   | ✅ Layar merespons di **SPI mode 3**, RES dipulsakan dari GPIO 5                                                                                                          |
| Tulisan "TFT OK" lewat library Adafruit (`tft_render_message`) | `bench`    | ✅ Tampil (mode 3 + RES GPIO 5)                                                                                                                                           |
| QR lewat `tft_render_qr`                                       | `bench`    | ⏳ **Belum tampil.** Penyebab belum diketahui. Belum dicek: baris Serial `[TFT] Locker 0 render QR: ...` dan nilai balik `qrcode_initText`. Lanjut dengan tes mentah dulu |
| Limit switch                                                   | —          | ⏳ Ditunda                                                                                                                                                                |
| Relay + solenoid                                               | —          | ⏳ Belum                                                                                                                                                                  |
| WiFi + `/sync` bersama TFT                                     | `esp32dev` | ⏳ Belum                                                                                                                                                                  |

## Konfigurasi TFT (hasil bench test)

- **Modul:** ST7789 1.3" 240×240, **7 pin tanpa CS**: GND, VCC, SCL, SDA, RES, DC, BLK.
- **SPI mode 3** — di library: `init(240, 240, SPI_MODE3)`.
- **RES lewat GPIO 5** (`TFT_RST_PIN`, default 5 di `tft_render.cpp`), bukan ke 3V3. Percobaan dengan RES ke 3V3 (mode 0 dan mode 3) dan RES GPIO + mode 2 tidak menghasilkan tampilan; kombinasi **mode 3 + RES GPIO 5** berhasil.
- Pin CS di `config.h` (4, 13, 14, 33) tetap diteruskan ke library, tetapi tidak berpengaruh pada modul tanpa pin CS.

Wiring bench (1 layar):

| Pin TFT | ESP32              |
| ------- | ------------------ |
| GND     | GND                |
| VCC     | 3V3                |
| SCL     | GPIO 18            |
| SDA     | GPIO 23            |
| DC      | GPIO 16            |
| RES     | GPIO 5             |
| BLK     | 3V3 (atau GPIO 19) |

> **Catatan 2 layar (analisis, belum diuji):** tanpa pin CS, layar tidak bisa dipilih lewat chip select. Dua layar yang berbagi SCL/SDA akan menerima data yang sama. Perlu diputuskan: modul yang punya pin CS, atau bus SPI terpisah per layar.

## Perubahan Firmware Terbaru (belum diuji di hardware)

**`main.cpp`**

- **Auto-lock:** setelah `lock_open()`, locker dikunci lagi saat pintu **tertutup setelah pernah terbuka** (transisi debounced), atau saat `UNLOCK_HOLD_MS` (default 10 detik) habis. Batas waktu melindungi solenoid dari dialiri arus terus-menerus.
  _Asumsi yang perlu dikonfirmasi dengan solenoid fisik:_ baut kunci bisa masuk kembali saat pintu didorong menutup (jenis baut miring/latch).
- **`openLatch`:** backend mendeteksi pintu dari nilai `door_open` tiap `/sync`. Kalau pintu dibuka-tutup di antara dua sync, transisi tidak terlihat. Latch memastikan "pernah terbuka" tetap terlapor sekali di sync berikutnya.
- **`forceSync`:** sync dijalankan segera saat limit switch berubah, tanpa menunggu interval 2 detik.
- `lock_init()` dipanggil paling awal di `setup()` (relay OFF sebelum urusan WiFi).
- QR di TFT digambar ulang **hanya saat token berubah** (hindari flicker), maksimal 1 layar per siklus sync.
- Konflik merge git yang sempat tersisa di file ini sudah dibersihkan.

**`door_sensor.cpp`**

- State awal dibaca dari pin (bukan diasumsikan "tertutup") — tidak ada transisi palsu saat boot.
- Debounce "stabil selama `SENSOR_DEBOUNCE_MS`" menggantikan pembatas laju.
- Hanya memproses `ACTIVE_LOCKERS`. Pin input-only (34/35/36/39) memakai `INPUT` biasa karena tidak punya pull-up internal; **resistor pull-up 10 kΩ eksternal tetap wajib**.

**`tft_render.cpp`**

- SPI mode 3 + RES via `TFT_RST_PIN` (lihat Konfigurasi TFT).
- Warna QR dibalik menjadi **modul hitam di latar putih** (QR standar, lebih mudah dibaca scanner).

**`platformio.ini`**

- Tiga env: `esp32dev` (firmware penuh), `bench` (tes TFT dengan library), `rawtft` (tes TFT mentah). Flag `-D CONFIG_...` dihapus karena tidak berpengaruh pada core Arduino yang sudah terkompilasi.
- Ditambah `monitor_filters = default, esp32_exception_decoder` agar backtrace crash terbaca.

## Skala & Konfigurasi

- Skala prototype = **2 locker** (lihat `DOKUMENTASI_PROGRESS_BACKEND.md` dan wiring guide).
- ⚠️ `config.h` yang terakhir dicek: `BUILD_MODE_DEVELOPMENT` → `ACTIVE_LOCKERS 1`, `ENABLE_TFT false`, `ENABLE_DOOR_SENSOR false`; `BUILD_MODE_PRODUCTION` → `ACTIVE_LOCKERS 4`. Samakan dengan skala 2 locker sebelum integrasi.
- Untuk menguji TFT lewat firmware penuh: `ENABLE_TFT true`, `ENABLE_DOOR_SENSOR false`, `ACTIVE_LOCKERS 1`.

## Hardware Target

- **Board:** ESP32 38-pin NodeMCU (ESP32-D0WDQ6-V3)
- **Display:** TFT IPS ST7789 1.3" 240×240 (1 per locker)
- **Relay:** 4-channel (aktif LOW)
- **Sensor:** limit switch / reed magnet (1 per locker). Limit switch: gunakan terminal **C + NO** (tertekan = pintu tertutup = LOW)
- **Solenoid:** 12V fail-secure

### Wajib untuk Sensor (pin 34-39)

GPIO 34, 35, 36, 39 adalah **input-only** dan tidak punya internal pull-up.
Setiap sensor magnet / limit switch harus dipasang **resistor pull-up 10kΩ**
dari pin sensor ke 3.3V. Tanpa resistor ini, pin floating dan pembacaan
random (flapping).

Diagram:

```text
3.3V ──[ 10kΩ ]──┬──── GPIO 34
                 │
              Sensor / limit switch (ke GND saat pintu tertutup)
```

## Pin Mapping

| Fungsi            | Pin                                |
| ----------------- | ---------------------------------- |
| Relay 0-3         | 25, 26, 27, 32                     |
| Sensor 0-3        | 34, 35, 36, 39                     |
| Status LED        | 2                                  |
| TFT SCLK (shared) | 18                                 |
| TFT MOSI (shared) | 23                                 |
| TFT BLK (shared)  | 19 (atau langsung 3V3)             |
| TFT RES           | 5 (`TFT_RST_PIN`, modul tanpa CS)  |
| TFT CS 0-3        | 4, 13, 14, 33 (hanya modul ber-CS) |
| TFT DC 0-3        | 16, 17, 21, 22                     |

## Struktur Kode

```text
src/
├── main.cpp              # setup + loop (sync, auto-lock, render QR)
├── config.h              # WiFi, URL, pin mapping
├── wifi_client.h/.cpp    # koneksi WiFi + reconnect
├── backend_poller.h/.cpp # POST /sync + parse JSON
├── lock_control.h/.cpp   # relay control
├── door_sensor.h/.cpp    # baca sensor pintu (debounce)
├── event_reporter.h/.cpp # POST /report (tidak dipakai di alur /sync)
├── tft_render.h/.cpp     # render QR ke TFT ST7789
├── bench_test.cpp        # tes TFT dengan library (env bench)
└── tft_raw_test.cpp      # tes TFT mentah tanpa library (env rawtft)
```

## Cara Build

```bash
cd firmware/smart-locker
pio run -e esp32dev -t upload   # firmware penuh
pio run -e bench -t upload      # tes TFT dengan library (teks + QR)
pio run -e rawtft -t upload     # tes TFT mentah (SPI mode 3)
pio device monitor -b 115200    # Serial Monitor
```

## Cara Test

**Tes TFT mentah (`rawtft`)** — paling dasar, tanpa library:

1. Wiring sesuai tabel "Wiring bench".
2. Upload. Layar berganti merah → hijau → biru → putih tiap 1,5 detik.
3. Serial: `[RAW] init selesai (RES pin: 5)`, lalu nama warna.

**Tes TFT dengan library (`bench`):**

1. Serial: `[TFT] Init locker 0 (CS=4, DC=16, RST=5)`.
2. Layar menampilkan "TFT OK", lalu QR berganti tiap 5 detik (token uji `tok0001`, dst.).
3. Status saat ini: tulisan tampil, QR belum.

**Tanpa hardware lengkap:**

1. **Koneksi WiFi + sync:** upload, lihat log `[Sync] OK` + `[QR] Locker 0 token: xxxxxx`.
2. **Sensor pintu:** colok kabel jumper dari GPIO 34 ke GND (dengan pull-up terpasang).
3. **Command unlock:** rent locker via Thunder Client, lihat `[Cmd] Locker 0: UNLOCK`, lalu `[Lock] Kunci` (pintu tertutup atau batas waktu).

## Troubleshooting

| Gejala                                                               | Kemungkinan                                                       | Solusi                                                                                                                                       |
| -------------------------------------------------------------------- | ----------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------- |
| `pins_arduino.h: No such file or directory` saat build               | Paket framework Arduino-ESP32 di PlatformIO tidak lengkap         | Hapus folder `framework-arduinoespressif32` di `.platformio\packages` (folder `.platformio` tersembunyi), lalu build ulang agar diunduh lagi |
| `undefined reference to setup()/loop()` di env `rawtft` atau `bench` | File tes tidak ikut terkompilasi oleh `build_src_filter`          | Pastikan nama file persis dan berada di `src/`; `pio run -e <env> -t clean` lalu build ulang                                                 |
| Penanda `<<<<<<<` / `>>>>>>>` di `main.cpp`                          | Konflik merge git belum diselesaikan                              | Hapus penanda, gabungkan kedua sisi                                                                                                          |
| TFT: backlight menyala, layar gelap                                  | Modul tanpa CS butuh SPI mode 3 + RES dari GPIO                   | `init(240, 240, SPI_MODE3)` dan sambungkan RES ke GPIO 5                                                                                     |
| ESP32 reboot saat backend tidur                                      | Cold start Render (30–60 dtk) melebihi `WDT_TIMEOUT_SEC` (30 dtk) | Naikkan WDT atau pasang cron anti-sleep                                                                                                      |

## Dependencies

- `bblanchon/ArduinoJson` — parse JSON
- `adafruit/Adafruit ST7735 and ST7789 Library` — driver TFT
- `adafruit/Adafruit GFX Library` — primitive drawing
- `ricmoo/QRCode` — generate QR matrix

## Catatan

- **Endpoint firmware:** `POST /api/firmware/esp32_01/sync` (gabungan poll + report)
- **Request body:** `{ "lockers": [{ "index", "door_open", "solenoid_on" }] }`
- **Response:** `{ "commands": [...], "qr_tokens": {...} }`
- **Transition detection:** Backend mendeteksi transisi pintu dari perubahan state antar-sync (lihat `openLatch` untuk kasus buka-tutup cepat)
- **Watchdog:** `WDT_TIMEOUT_SEC 30`. Request HTTPS saat backend cold start bisa memblokir lebih lama dari itu.
- **Auto-lock** berjalan tiap iterasi loop, tetapi tidak berjalan saat `backend_sync` sedang memblokir.

## Endpoint Firmware: /sync

Firmware menggunakan **`POST /api/firmware/esp32_01/sync`** yang menggabungkan
polling perintah dan pelaporan state pintu dalam 1 request per 2 detik.

**Keuntungan:**

- Hemat ~50% request (sebelumnya 2 endpoint: /poll + /report)
- ESP32 tidak perlu track "kapan harus report" — cukup kirim state
- Backend yang urus deteksi transisi (state centered di backend)

**Endpoint lama** (`/poll` dan `/report`) tetap ada untuk backward compatibility.

## Autentikasi Device

Firmware mengirim header `X-Device-Token` di setiap request ke endpoint
`/api/firmware/*`. Token harus cocok dengan field `authToken` di
Firestore collection `controllers/{controller_id}`.

Token di-seed via `backend-express/seedController.js`. Cara pakai:

```bash
cd backend-express
node seedController.js
# Output: [seed] authToken: <DEVICE_TOKEN>
```

> Jangan menulis token asli di dokumen atau commit. Salin dari output seed atau dari Firestore (`controllers/esp32_01.authToken`) ke `DEVICE_TOKEN` di `config.h`.

## Progress & TODO

- [x] WiFi client (connect + reconnect)
- [x] Backend poller (`POST /sync`)
- [x] Lock control (relay)
- [x] Door sensor (debounce) — direvisi 15 Okt
- [x] Event reporter (`POST /report`) — tidak dipakai di alur `/sync`
- [x] TFT render + QR generation (kode ada)
- [x] Device auth token (`X-Device-Token`)
- [x] Watchdog (30 dtk) — brownout protection belum
- [x] TFT merespons di hardware (SPI mode 3 + RES GPIO 5)
- [ ] **QR tampil di TFT** (debug: cek `qrcode_initText`, Serial, urutan penggambaran)
- [ ] Uji limit switch di hardware (ditunda)
- [ ] Build & uji firmware penuh (`esp32dev`) dengan `main.cpp` revisi
- [ ] Uji relay + solenoid, konfirmasi baut kunci bisa re-latch saat pintu ditutup
- [ ] Samakan `ACTIVE_LOCKERS` di `config.h` dengan skala 2 locker
- [ ] Putuskan solusi 2 TFT tanpa pin CS
- [ ] Atasi cold start Render vs watchdog (naikkan WDT atau anti-sleep)
- [ ] Multi-locker scaling test
- [ ] Brownout protection
