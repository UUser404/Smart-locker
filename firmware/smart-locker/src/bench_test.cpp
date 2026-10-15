// Bench test: 1 TFT + 1 limit switch (locker 0), tanpa WiFi/backend/relay.
// Letakkan di firmware/smart-locker/src/ lalu build dengan: pio run -e bench -t upload
#include <Arduino.h>
#include "config.h"
#include "tft_render.h"
#include "door_sensor.h"

void setup()
{
    Serial.begin(115200);
    delay(500);
    Serial.println("[BENCH] mulai");

    tft_init();
    tft_render_message(0, "TFT OK", "Tekan switch");

    door_init();
    Serial.printf("[BENCH] raw awal GPIO%d = %d (HIGH=terbuka, LOW=tertutup)\n",
                  SENSOR_PINS[0], digitalRead(SENSOR_PINS[0]));
}

void loop()
{
    int t = door_check_transition(0);

    if (t == 1)
    {
        Serial.println("[BENCH] PINTU TERBUKA");
        tft_render_message(0, "PINTU", "TERBUKA");
    }
    else if (t == -1)
    {
        Serial.println("[BENCH] PINTU TERTUTUP -> tampilkan QR uji");
        tft_render_qr(0, "locker_01", "abc123");
    }

    // Cetak nilai mentah tiap 1 detik, untuk cek pantulan / pull-up
    static unsigned long lastPrint = 0;
    if (millis() - lastPrint >= 1000)
    {
        lastPrint = millis();
        Serial.printf("[BENCH] raw=%d\n", digitalRead(SENSOR_PINS[0]));
    }
}