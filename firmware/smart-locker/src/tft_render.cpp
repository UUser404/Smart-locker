#include "tft_render.h"
#include "config.h"
#include <Adafruit_GFX.h>
#include <Adafruit_ST7789.h>
#include <SPI.h>
#include <qrcode.h>

// Pin RES TFT (modul tanpa CS butuh reset dari GPIO, tidak cukup ke 3V3).
#ifndef TFT_RST_PIN
#define TFT_RST_PIN 5
#endif

// 1 = mode diagnostik (log detail + penanda sudut + dump ASCII QR ke Serial)
// 0 = mode normal. Setelah QR beres, ubah ke 0.
#ifndef TFT_DIAG
#define TFT_DIAG 0
#endif

// QR standar: modul gelap di latar terang (agar bisa dibaca kamera/scanner)
#define QR_DARK_COLOR 0x0000
#define QR_LIGHT_COLOR 0xFFFF

static Adafruit_ST7789 *tft[NUM_LOCKERS] = {nullptr};

void tft_init()
{
  // Setup backlight
  pinMode(TFT_BLK_PIN, OUTPUT);
  digitalWrite(TFT_BLK_PIN, HIGH);
  delay(50);

  // Inisialisasi hardware SPI
  SPI.begin(TFT_SCLK_PIN, -1, TFT_MOSI_PIN, -1);

  for (int i = 0; i < ACTIVE_LOCKERS; i++)
  {
    tft[i] = new Adafruit_ST7789(TFT_CS_PINS[i], TFT_DC_PINS[i], TFT_RST_PIN);

    // Modul tanpa pin CS terbukti hanya merespons di SPI mode 3
    tft[i]->init(240, 240, SPI_MODE3);
    tft[i]->setRotation(0);
    tft[i]->fillScreen(TFT_BG_COLOR);

    Serial.printf("[TFT] Init locker %d (CS=%d, DC=%d, RST=%d)\n", i,
                  TFT_CS_PINS[i], TFT_DC_PINS[i], TFT_RST_PIN);
  }
}

void tft_clear(int idx)
{
  if (idx < 0 || idx >= ACTIVE_LOCKERS || tft[idx] == nullptr)
    return;
  tft[idx]->fillScreen(TFT_BG_COLOR);
}

void tft_render_qr(int idx, const char *lockerId, const char *token)
{
  if (idx < 0 || idx >= ACTIVE_LOCKERS || tft[idx] == nullptr)
  {
    Serial.printf("[TFT] render_qr dibatalkan: idx=%d tft=%s\n", idx,
                  (idx >= 0 && idx < NUM_LOCKERS && tft[idx]) ? "ada" : "null");
    return;
  }

  // Bangun string QR: "locker_01.9f3a1c"
  String qrText = String(lockerId) + "." + String(token);
  Serial.printf("[TFT] Locker %d render QR: %s (panjang=%d)\n", idx,
                qrText.c_str(), (int)qrText.length());

  // Generate QR matrix
  QRCode qrcode;
  uint8_t qrcodeData[qrcode_getBufferSize(QR_VERSION)];
  int8_t rc = qrcode_initText(&qrcode, qrcodeData, QR_VERSION, QR_ECC_LEVEL,
                              qrText.c_str());

#if TFT_DIAG
  Serial.printf("[TFT] qr rc=%d versi=%d size=%d buffer=%d byte\n", rc,
                QR_VERSION, qrcode.size, (int)qrcode_getBufferSize(QR_VERSION));
  Serial.printf("[TFT] heap bebas=%u byte, sisa stack=%u byte\n",
                (unsigned)ESP.getFreeHeap(),
                (unsigned)uxTaskGetStackHighWaterMark(NULL));
#endif

  if (rc != 0)
  {
    Serial.println("[TFT] ERROR: pembuatan QR gagal, penggambaran dibatalkan");
    tft_render_message(idx, "QR GAGAL", "rc != 0");
    return;
  }

  // Hitung ukuran per modul (pixel)
  int moduleSize = QR_SIZE_PX / (qrcode.size + QR_QUIET_ZONE * 2);
  if (moduleSize < 2)
    moduleSize = 2; // minimal 2 pixel per modul

  // Hitung offset agar QR di tengah
  int totalQrSize = (qrcode.size + QR_QUIET_ZONE * 2) * moduleSize;
  int offsetX = (TFT_WIDTH - totalQrSize) / 2;
  int offsetY = (TFT_HEIGHT - totalQrSize) / 2;

#if TFT_DIAG
  Serial.printf("[TFT] moduleSize=%d total=%d offset=(%d,%d)\n", moduleSize,
                totalQrSize, offsetX, offsetY);

  // Dump QR sebagai ASCII + hitung modul gelap
  int dark = 0;
  for (uint8_t y = 0; y < qrcode.size; y++)
  {
    String row;
    row.reserve(qrcode.size * 2 + 1);
    for (uint8_t x = 0; x < qrcode.size; x++)
    {
      bool m = qrcode_getModule(&qrcode, x, y);
      if (m)
        dark++;
      row += m ? "##" : "  ";
    }
    Serial.println(row);
  }
  Serial.printf("[TFT] modul gelap=%d dari %d\n", dark,
                qrcode.size * qrcode.size);
#endif

  unsigned long t0 = millis();

  // Latar putih (sekaligus quiet zone)
  tft[idx]->fillScreen(QR_LIGHT_COLOR);
  Serial.println("[TFT] fillScreen putih selesai");

#if TFT_DIAG
  // Penanda 4 sudut: merah kiri-atas, hijau kanan-atas,
  // biru kiri-bawah, hitam kanan-bawah (semua 20x20 px)
  tft[idx]->fillRect(0, 0, 20, 20, 0xF800);
  tft[idx]->fillRect(TFT_WIDTH - 20, 0, 20, 20, 0x07E0);
  tft[idx]->fillRect(0, TFT_HEIGHT - 20, 20, 20, 0x001F);
  tft[idx]->fillRect(TFT_WIDTH - 20, TFT_HEIGHT - 20, 20, 20, 0x0000);
  Serial.println("[TFT] penanda sudut tergambar, tunggu 1.5 dtk");
  delay(1500);
#endif

  // Gambar hanya modul gelap.
  // Tanpa startWrite()/endWrite() di luar: fillRect sudah mengatur transaksi
  // SPI sendiri (sama seperti penanda sudut yang terbukti tampil).
  int drawn = 0;
  for (uint8_t y = 0; y < qrcode.size; y++)
  {
    for (uint8_t x = 0; x < qrcode.size; x++)
    {
      if (!qrcode_getModule(&qrcode, x, y))
        continue;
      int px = offsetX + (x + QR_QUIET_ZONE) * moduleSize;
      int py = offsetY + (y + QR_QUIET_ZONE) * moduleSize;
      tft[idx]->fillRect(px, py, moduleSize, moduleSize, QR_DARK_COLOR);
      drawn++;
    }
  }

  Serial.printf("[TFT] QR selesai digambar: %d kotak, %lu ms\n", drawn,
                millis() - t0);
}

void tft_render_message(int idx, const char *line1, const char *line2)
{
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