# Smart Locker Firmware (ESP32)

Firmware ESP32 untuk sistem Smart Locker IoT. Berkomunikasi dengan backend Express di Render via HTTPS, mengeksekusi perintah unlock, melaporkan event pintu, dan menampilkan QR dinamis di layar TFT.

## Status Saat Ini

| Modul | Status | Catatan |
|---|---|---|
| `wifi_client` | ✅ Tested | Koneksi ke WiFi kampus + reconnect |
| `backend_poller` | ✅ Tested | Poll `GET /poll` tiap 2 detik, parse JSON |
| `lock_control` | ⚠️ Written | Butuh relay, belum test hardware |
| `door_sensor` | ⚠️ Written | Tested via jumper manual |
| `event_reporter` | ⚠️ Written | Belum test end-to-end (quota Firestore habis) |
| `tft_render` | ⚠️ Written | Dry-run compile OK, butuh TFT ST7789 |

## Hardware Target

- **Board:** ESP32 38-pin NodeMCU (ESP32-D0WDQ6-V3)
- **Display:** 4x TFT IPS ST7789 1.3" 240×240 (1 per locker)
- **Relay:** 4-channel (aktif LOW)
- **Sensor:** 4x limit switch / reed magnet
- **Solenoid:** 4x 12V fail-secure

## Pin Mapping

| Fungsi | Pin |
|---|---|
| Relay 0-3 | 25, 26, 27, 32 |
| Sensor 0-3 | 34, 35, 36, 39 |
| Status LED | 2 |
| TFT SCLK (shared) | 18 |
| TFT MOSI (shared) | 23 |
| TFT BLK (shared) | 19 |
| TFT CS 0-3 | 4, 13, 14, 33 |
| TFT DC 0-3 | 16, 17, 21, 22 |

## Struktur Kode

```text
src/
├── main.cpp              # setup + loop
├── config.h              # WiFi, URL, pin mapping
├── wifi_client.h/.cpp    # koneksi WiFi + reconnect
├── backend_poller.h/.cpp # GET /poll + parse JSON
├── lock_control.h/.cpp   # relay control
├── door_sensor.h/.cpp    # baca sensor pintu
├── event_reporter.h/.cpp # POST /report
└── tft_render.h/.cpp     # render QR ke TFT ST7789
```

## Cara Build

```bash
cd firmware/smart-locker
pio run               # compile saja
pio run -t upload     # upload ke ESP32
pio device monitor    # buka Serial Monitor
```

## Cara Test Tanpa Hardware

1. **Koneksi WiFi + polling:** upload, lihat log `[Poll] OK` + `[QR] Locker 0 token: xxxxxx`
2. **Sensor pintu:** colok kabel jumper dari GPIO 34 ke GND, lihat `[Door] Locker 0: pintu tertutup`
3. **Command unlock:** rent locker via Thunder Client, lihat `[Cmd] Locker 0: UNLOCK`
4. **TFT:** belum bisa ditest tanpa hardware

## Dependencies

- `bblanchon/ArduinoJson` — parse JSON
- `adafruit/Adafruit ST7735 and ST7789 Library` — driver TFT
- `adafruit/Adafruit GFX Library` — primitive drawing
- `ricmoo/QRCode` — generate QR matrix

## Catatan

- **Token QR format:** `{locker_id}.{token}`, contoh: `locker_01.9f3a1c`
- **Poll interval:** 2 detik (kontrak `API.md`)
- **Token rotation:** 5 detik (backend rotator, in-memory)
- **TLS:** pakai `setInsecure()` untuk dev, wajib `setCACert()` untuk production
- **Backend URL:** `https://smart-locker-backend-a2ck.onrender.com/api`

## Progress & TODO

- [x] WiFi client (connect + reconnect)
- [x] Backend poller (`GET /poll`)
- [x] Lock control (relay stub)
- [x] Door sensor (debounce)
- [x] Event reporter (`POST /report`)
- [x] TFT render + QR generation
- [ ] Test end-to-end dengan hardware (menunggu komponen dari Alfian)
- [ ] Multi-locker scaling test (4 locker simultan)
- [ ] Watchdog + brownout protection
- [ ] Device auth token (untuk production)