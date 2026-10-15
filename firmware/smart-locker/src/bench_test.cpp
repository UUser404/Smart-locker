// Bench test TFT saja (locker 0). Tanpa WiFi, backend, relay, atau limit switch.
// Letakkan di firmware/smart-locker/src/ lalu: pio run -e bench -t upload
#include <Arduino.h>
#include "config.h"
#include "tft_render.h"

void setup()
{
    Serial.begin(115200);
    delay(500);
    Serial.println("[BENCH] TFT saja");

    tft_init();
    tft_render_message(0, "TFT OK", "locker 0");
    delay(2000);

    tft_render_qr(0, "locker_01", "abc123");
    Serial.println("[BENCH] QR 1 tampil: locker_01.abc123");
}

void loop()
{
    // Ganti token tiap 5 detik untuk menguji redraw (mirip rotasi QR asli)
    static unsigned long last = 0;
    static int n = 0;
    if (millis() - last >= 5000)
    {
        last = millis();
        n++;
        char tok[16];
        snprintf(tok, sizeof(tok), "tok%04d", n);
        tft_render_qr(0, "locker_01", tok);
        Serial.printf("[BENCH] QR baru: locker_01.%s\n", tok);
    }
}