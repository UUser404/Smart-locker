// Bench test limit switch + debounce (locker 0), TFT tetap terpasang.
// Tanpa WiFi, backend, dan relay.
// Letakkan di firmware/smart-locker/src/ lalu: pio run -e benchdoor -t upload
//
// Yang diukur: berapa kali pin berubah mentah (bounce) untuk SATU tekan/lepas,
// berapa lama bounce-nya, dan apakah debounce menghasilkan tepat 1 event.
#include <Arduino.h>
#include "config.h"
#include "tft_render.h"
#include "door_sensor.h"

#if ACTIVE_LOCKERS != 1
#error "Tes ini butuh ACTIVE_LOCKERS 1 (satu layar). Set BUILD_MODE_DEVELOPMENT di config.h."
#endif

static int lastRaw = -1;
static unsigned long firstEdgeUs = 0;
static unsigned long lastEdgeUs = 0;
static int rawEdges = 0; // perubahan pin mentah sejak event terakhir
static int events = 0;   // jumlah transisi lolos debounce

static void show(bool open)
{
    char line2[20];
    snprintf(line2, sizeof(line2), "event: %d", events);
    tft_render_message(0, open ? "TERBUKA" : "TERTUTUP", line2);
}

void setup()
{
    Serial.begin(115200);
    delay(500);
    Serial.println("[BENCH-DOOR] tes limit switch + debounce");
    Serial.printf("[BENCH-DOOR] GPIO %d, debounce %d ms\n", SENSOR_PINS[0],
                  SENSOR_DEBOUNCE_MS);
    Serial.println("[BENCH-DOOR] raw=1 (HIGH) = terbuka, raw=0 (LOW) = tertutup");

    tft_init();
    door_init();

    lastRaw = digitalRead(SENSOR_PINS[0]);
    show(door_is_open(0));
}

void loop()
{
    // 1) Catat setiap perubahan pin mentah (tanpa debounce)
    int raw = digitalRead(SENSOR_PINS[0]);
    if (raw != lastRaw)
    {
        unsigned long now = micros();
        if (rawEdges == 0)
            firstEdgeUs = now;
        lastEdgeUs = now;
        rawEdges++;
        lastRaw = raw;
    }

    // 2) Transisi yang lolos debounce (harus dipanggil tiap loop)
    int t = door_check_transition(0);
    if (t != 0)
    {
        events++;
        bool open = (t == 1);
        unsigned long bounceMs = (lastEdgeUs - firstEdgeUs) / 1000;
        unsigned long latencyMs = (micros() - firstEdgeUs) / 1000;
        Serial.printf(
            "[DOOR] #%d %s | tepi mentah=%d | bounce=%lu ms | latensi=%lu ms\n",
            events, open ? "TERBUKA" : "TERTUTUP", rawEdges, bounceMs,
            latencyMs);
        rawEdges = 0;
        show(open);
    }

    // 3) Derau: pin berubah tapi tidak ada transisi lolos debounce
    if (rawEdges > 0 && (micros() - lastEdgeUs) > 500000UL)
    {
        Serial.printf("[DOOR] derau: %d tepi mentah diabaikan debounce\n",
                      rawEdges);
        rawEdges = 0;
    }

    // 4) Status berkala
    static unsigned long lastPrint = 0;
    if (millis() - lastPrint >= 2000)
    {
        lastPrint = millis();
        int r = digitalRead(SENSOR_PINS[0]);
        Serial.printf("[BENCH-DOOR] raw=%d (%s)\n", r,
                      r == HIGH ? "terbuka" : "tertutup");
    }
}