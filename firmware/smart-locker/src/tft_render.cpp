#include "tft_render.h"
#include "config.h"
#include <Adafruit_GFX.h>
#include <Adafruit_ST7789.h>
#include <SPI.h>
#include <qrcode.h>

// Buat instance TFT per locker (4 unit)
// RST = -1 karena kita tie ke 3.3V
static Adafruit_ST7789 *tft[NUM_LOCKERS] = {nullptr};

void tft_init() {
  // Setup backlight
  pinMode(TFT_BLK_PIN, OUTPUT);
  digitalWrite(TFT_BLK_PIN, HIGH);
  delay(50);

  // Inisialisasi hardware SPI
  SPI.begin(TFT_SCLK_PIN, -1, TFT_MOSI_PIN, -1);

  for (int i = 0; i < ACTIVE_LOCKERS; i++) {
    tft[i] = new Adafruit_ST7789(TFT_CS_PINS[i], TFT_DC_PINS[i], -1);

    tft[i]->init(240, 240);
    tft[i]->setRotation(0);
    tft[i]->fillScreen(TFT_BG_COLOR);

    Serial.printf("[TFT] Init locker %d (CS=%d, DC=%d)\n", i, TFT_CS_PINS[i],
                  TFT_DC_PINS[i]);
  }
}

void tft_clear(int idx) {
  if (idx < 0 || idx >= ACTIVE_LOCKERS || tft[idx] == nullptr)
    return;
  tft[idx]->fillScreen(TFT_BG_COLOR);
}

void tft_render_qr(int idx, const char *lockerId, const char *token) {
  if (idx < 0 || idx >= ACTIVE_LOCKERS || tft[idx] == nullptr)
    return;

  // Bangun string QR: "locker_01.9f3a1c"
  String qrText = String(lockerId) + "." + String(token);

  Serial.printf("[TFT] Locker %d render QR: %s\n", idx, qrText.c_str());

  // Generate QR matrix
  QRCode qrcode;
  uint8_t qrcodeData[qrcode_getBufferSize(QR_VERSION)];
  qrcode_initText(&qrcode, qrcodeData, QR_VERSION, QR_ECC_LEVEL,
                  qrText.c_str());

  // Hitung ukuran per modul (pixel)
  int moduleSize = QR_SIZE_PX / (qrcode.size + QR_QUIET_ZONE * 2);
  if (moduleSize < 2)
    moduleSize = 2; // minimal 2 pixel per modul

  // Hitung offset agar QR di tengah
  int totalQrSize = (qrcode.size + QR_QUIET_ZONE * 2) * moduleSize;
  int offsetX = (TFT_WIDTH - totalQrSize) / 2;
  int offsetY = (TFT_HEIGHT - totalQrSize) / 2;

  // Clear screen + gambar
  tft[idx]->fillScreen(TFT_BG_COLOR);
  tft[idx]->startWrite();

  // Render tiap modul QR
  for (uint8_t y = 0; y < qrcode.size; y++) {
    for (uint8_t x = 0; x < qrcode.size; x++) {
      uint16_t color =
          qrcode_getModule(&qrcode, x, y) ? TFT_FG_COLOR : TFT_BG_COLOR;
      int px = offsetX + (x + QR_QUIET_ZONE) * moduleSize;
      int py = offsetY + (y + QR_QUIET_ZONE) * moduleSize;
      tft[idx]->fillRect(px, py, moduleSize, moduleSize, color);
    }
  }

  tft[idx]->endWrite();
}

void tft_render_message(int idx, const char *line1, const char *line2) {
  if (idx < 0 || idx >= ACTIVE_LOCKERS || tft[idx] == nullptr)
    return;

  tft[idx]->fillScreen(TFT_BG_COLOR);
  tft[idx]->setTextColor(TFT_TEXT_COLOR);
  tft[idx]->setTextSize(2);

  tft[idx]->setCursor(20, 80);
  tft[idx]->println(line1);

  tft[idx]->setCursor(20, 120);
  tft[idx]->println(line2);
}