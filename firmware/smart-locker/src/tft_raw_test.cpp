// Tes mentah ST7789 240x240 TANPA library Adafruit.
// SPI mode 3 saja (terbukti merespons di modul ini), RES lewat GPIO.
// Layar berganti MERAH -> HIJAU -> BIRU -> PUTIH terus-menerus.
#include <Arduino.h>
#include <SPI.h>

#define PIN_SCLK 18
#define PIN_MOSI 23
#define PIN_DC 16
#define PIN_RES 5 // GPIO untuk RES. Isi -1 kalau RES masih disambung ke 3V3.

static const uint8_t SPI_MODE_USED = SPI_MODE3;
static const uint32_t SPI_HZ = 4000000;

static void cmd(uint8_t c)
{
    digitalWrite(PIN_DC, LOW);
    SPI.beginTransaction(SPISettings(SPI_HZ, MSBFIRST, SPI_MODE_USED));
    SPI.transfer(c);
    SPI.endTransaction();
}

static void d8(uint8_t v)
{
    digitalWrite(PIN_DC, HIGH);
    SPI.beginTransaction(SPISettings(SPI_HZ, MSBFIRST, SPI_MODE_USED));
    SPI.transfer(v);
    SPI.endTransaction();
}

static void st7789_init()
{
    if (PIN_RES >= 0)
    {
        pinMode(PIN_RES, OUTPUT);
        digitalWrite(PIN_RES, HIGH);
        delay(10);
        digitalWrite(PIN_RES, LOW);
        delay(20);
        digitalWrite(PIN_RES, HIGH);
        delay(150);
    }
    cmd(0x01); // software reset
    delay(150);
    cmd(0x11); // sleep out
    delay(120);
    cmd(0x3A); // pixel format
    d8(0x55);  // RGB565
    cmd(0x36); // orientasi
    d8(0x00);
    cmd(0x21); // inversi ON (umum untuk IPS 240x240)
    cmd(0x13); // normal display
    delay(10);
    cmd(0x29); // display ON
    delay(100);
}

static void fill(uint16_t color)
{
    cmd(0x2A); // kolom 0..239
    d8(0);
    d8(0);
    d8(0);
    d8(239);
    cmd(0x2B); // baris 0..239
    d8(0);
    d8(0);
    d8(0);
    d8(239);
    cmd(0x2C); // mulai tulis RAM

    uint8_t line[480];
    for (int i = 0; i < 240; i++)
    {
        line[2 * i] = color >> 8;
        line[2 * i + 1] = color & 0xFF;
    }
    digitalWrite(PIN_DC, HIGH);
    SPI.beginTransaction(SPISettings(SPI_HZ, MSBFIRST, SPI_MODE_USED));
    for (int y = 0; y < 240; y++)
        SPI.writeBytes(line, 480);
    SPI.endTransaction();
}

void setup()
{
    Serial.begin(115200);
    delay(500);
    Serial.println("[RAW] tes ST7789 mentah, SPI mode 3");
    pinMode(PIN_DC, OUTPUT);
    SPI.begin(PIN_SCLK, -1, PIN_MOSI, -1);
    st7789_init();
    Serial.printf("[RAW] init selesai (RES pin: %d)\n", PIN_RES);
}

void loop()
{
    fill(0xF800); // merah
    Serial.println("[RAW] merah");
    delay(1500);
    fill(0x07E0); // hijau
    Serial.println("[RAW] hijau");
    delay(1500);
    fill(0x001F); // biru
    Serial.println("[RAW] biru");
    delay(1500);
    fill(0xFFFF); // putih
    Serial.println("[RAW] putih");
    delay(1500);
}