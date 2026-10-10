#ifndef CONFIG_H
#define CONFIG_H

// ============================================================
// BUILD MODE
// ============================================================
// DEVELOPMENT : 1 locker, TFT rendering bisa dimatikan kalau layar belum ada
// PRODUCTION  : 4 locker, semua aktif
#define BUILD_MODE_PRODUCTION 1
#define BUILD_MODE_DEVELOPMENT 0

#define BUILD_MODE BUILD_MODE_DEVELOPMENT

// Bisa override manual — kalau hardware cuma ada 1, biarkan 1
#if BUILD_MODE == BUILD_MODE_PRODUCTION
#define ACTIVE_LOCKERS 4
#define ENABLE_TFT true
#else
#define ACTIVE_LOCKERS 1
#define ENABLE_TFT true // set false kalau TFT belum ada
#endif

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

// ============================================================
// PIN MAPPING
// ============================================================
const int RELAY_PINS[NUM_LOCKERS] = {25, 26, 27, 32};
const int SENSOR_PINS[NUM_LOCKERS] = {34, 35, 36, 39};

#define STATUS_LED_PIN 2

// ============================================================
// TFT ST7789 240x240
// ============================================================
#define TFT_SCLK_PIN 18
#define TFT_MOSI_PIN 23
#define TFT_BLK_PIN 19

const int TFT_CS_PINS[NUM_LOCKERS] = {4, 13, 14, 33};
const int TFT_DC_PINS[NUM_LOCKERS] = {16, 17, 21, 22};

#define TFT_WIDTH 240
#define TFT_HEIGHT 240

#define QR_VERSION 3
#define QR_ECC_LEVEL ECC_LOW
#define QR_SIZE_PX 200
#define QR_QUIET_ZONE 4

#define TFT_BG_COLOR 0x0000
#define TFT_FG_COLOR 0xFFFF
#define TFT_TEXT_COLOR 0x07FF

// ============================================================
// KONFIGURASI SENSOR
// ============================================================
#define SENSOR_DEBOUNCE_MS 50

// ============================================================
// KONFIGURASI WATCHDOG
// ============================================================
// Timeout WDT: 30 detik. Kalau loop hang > 30s, ESP32 auto-restart.
#define WDT_TIMEOUT_SEC 30

#endif