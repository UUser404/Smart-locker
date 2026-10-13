# Smart Locker Firmware (ESP32)

Firmware ESP32 untuk sistem Smart Locker IoT. Berkomunikasi dengan backend
Express di Render via HTTPS, mengeksekusi perintah unlock, melaporkan event
pintu, dan menampilkan QR dinamis di layar TFT.

## Status Saat Ini

| Modul          | Status     | Catatan                                       |
| -------------- | ---------- | --------------------------------------------- |
| wifi_client    | ✅ Tested  | Koneksi ke WiFi kampus + reconnect            |
| backend_poller | ✅ Tested  | Poll GET /poll tiap 2 detik, parse JSON       |
| lock_control   | ⚠️ Written | Butuh relay, belum test hardware              |
| door_sensor    | ⚠️ Written | Tested via jumper manual                      |
| event_reporter | ⚠️ Written | Belum test end-to-end (quota Firestore habis) |
| tft_render     | ⚠️ Written | Dry-run compile OK, butuh TFT ST7789          |

## Hardware Target

- **Board:** ESP32 38-pin NodeMCU (ESP32-D0WDQ6-V3)
- **Display:** 4x TFT IPS ST7789 1.3" 240×240 (1 per locker)
- **Relay:** 4-channel (aktif LOW)
- **Sensor:** 4x limit switch / reed magnet
- **Solenoid:** 4x 12V fail-secure

## Pin Mapping

| Fungsi            | Pin            |
| ----------------- | -------------- |
| Relay 0-3         | 25, 26, 27, 32 |
| Sensor 0-3        | 34, 35, 36, 39 |
| Status LED        | 2              |
| TFT SCLK (shared) | 18             |
| TFT MOSI (shared) | 23             |
| TFT BLK (shared)  | 19             |
| TFT CS 0-3        | 4, 13, 14, 33  |
| TFT DC 0-3        | 16, 17, 21, 22 |

## Struktur Kode
