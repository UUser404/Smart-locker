#ifndef CONFIG_H
#define CONFIG_H

// ============================================================
// KONFIGURASI WIFI
// ============================================================
#define WIFI_SSID "STTI"
#define WIFI_PASSWORD ""

// ============================================================
// KONFIGURASI BACKEND
// ============================================================
#define BACKEND_BASE_URL "https://smart-locker-backend-a2ck.onrender.com/api"
#define CONTROLLER_ID "esp32_01"

#define POLL_INTERVAL_MS 2000
#define HTTP_TIMEOUT_MS 10000

// ============================================================
// KONFIGURASI LOCKER
// ============================================================
#define NUM_LOCKERS 4
#define ACTIVE_LOCKERS 1 // ubah ke 4 saat semua hardware siap

// ============================================================
// PIN MAPPING
// ============================================================
// Relay (output) — 4 locker
const int RELAY_PINS[NUM_LOCKERS] = {25, 26, 27, 32};

// Sensor magnet / limit switch (input-only)
const int SENSOR_PINS[NUM_LOCKERS] = {34, 35, 36, 39};

// Status LED (built-in di banyak dev board)
#define STATUS_LED_PIN 2

// ============================================================
// TFT ST7789 240x240 (4 display, 1 per locker)
// ============================================================
#define TFT_SCLK_PIN 18
#define TFT_MOSI_PIN 23
#define TFT_BLK_PIN 19

const int TFT_CS_PINS[NUM_LOCKERS] = {4, 13, 14, 33};
const int TFT_DC_PINS[NUM_LOCKERS] = {16, 17, 21, 22};
// RST: tie ke 3.3V, tidak butuh GPIO

// Dimensi layar
#define TFT_WIDTH 240
#define TFT_HEIGHT 240

// QR config
#define QR_VERSION 3 // versi 3 = 29x29 modul, cukup untuk 15 char
#define QR_ECC_LEVEL ECC_LOW
#define QR_SIZE_PX 200  // ukuran render QR di layar (pixel)
#define QR_QUIET_ZONE 4 // quiet zone (modul)

// Warna
#define TFT_BG_COLOR 0x0000   // hitam
#define TFT_FG_COLOR 0xFFFF   // putih
#define TFT_TEXT_COLOR 0x07FF // cyan

// ============================================================
// KONFIGURASI SENSOR
// ============================================================
#define SENSOR_DEBOUNCE_MS 50

#endif