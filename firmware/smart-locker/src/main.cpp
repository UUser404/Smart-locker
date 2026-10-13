#include "backend_poller.h"
#include "config.h"
#include "door_sensor.h"
#include "event_reporter.h"
#include "lock_control.h"
#include "tft_render.h"
#include "wifi_client.h"
#include <Arduino.h>
#include <esp_task_wdt.h>

<<<<<<< HEAD
// Ganti dengan SSID WiFi Anda (pastikan tidak ada password atau kosongkan jika terbuka)
const char *ssid = "Ruang Kuliah 01                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          ";
const char *password = "";
=======
unsigned long lastPollMs = 0;
String lastRenderedToken[NUM_LOCKERS];
bool waitingForClose[NUM_LOCKERS] = {false};
>>>>>>> 17bde8fed24258b5ca2c2d59e67a5de797db2789

// Round-robin TFT update: index yang akan di-update pada siklus berikutnya
int nextTftToRender = 0;

// ============================================================
// SETUP
// ============================================================
void setup() {
  Serial.begin(115200);
  delay(1000);

  Serial.println();
  Serial.println("================================");
  Serial.println("Smart Locker Firmware v3.1 (sync)");
  Serial.println("================================");
  Serial.printf("[Sys] Build mode: %s\n", BUILD_MODE == BUILD_MODE_PRODUCTION
                                              ? "PRODUCTION"
                                              : "DEVELOPMENT");
  Serial.printf("[Sys] Active lockers: %d\n", ACTIVE_LOCKERS);

  pinMode(STATUS_LED_PIN, OUTPUT);

  Serial.print("[Sys] MAC Address: ");
  Serial.println(wifi_get_mac());

  if (!wifi_init()) {
    Serial.println("[Sys] WiFi gagal. Restart...");
    delay(3000);
    ESP.restart();
  }

  lock_init();

#if ENABLE_DOOR_SENSOR
  door_init();
#endif

#if ENABLE_TFT
  Serial.println("[Sys] Init TFT...");
  tft_init();
#endif

  // Init WDT
  esp_task_wdt_init(WDT_TIMEOUT_SEC, true);
  esp_task_wdt_add(NULL);
  Serial.printf("[Sys] Watchdog aktif: %d detik\n", WDT_TIMEOUT_SEC);

  for (int i = 0; i < NUM_LOCKERS; i++) {
    lastRenderedToken[i] = "";
    waitingForClose[i] = false;
  }

  Serial.println("[Sys] Setup selesai. Mulai sync.");
}

// ============================================================
// LOOP
// ============================================================
void loop() {
  // Reset watchdog setiap loop
  esp_task_wdt_reset();

  if (!wifi_check_and_reconnect()) {
    delay(3000);
    return;
  }

  // Sync backend tiap POLL_INTERVAL_MS
  if (millis() - lastPollMs < POLL_INTERVAL_MS)
    return;
  lastPollMs = millis();

  digitalWrite(STATUS_LED_PIN, !digitalRead(STATUS_LED_PIN));

  // ============================================================
  // Baca state pintu + solenoid semua locker
  // ============================================================
  bool doorOpen[NUM_LOCKERS] = {false};
  bool solenoidOn[NUM_LOCKERS] = {false};

  for (int i = 0; i < NUM_LOCKERS; i++) {
    if (i < ACTIVE_LOCKERS) {
#if ENABLE_DOOR_SENSOR
      doorOpen[i] = door_is_open(i);
#else
      // Dev mode: pin floating, kirim false supaya backend tidak deteksi
      // transisi palsu
      doorOpen[i] = false;
#endif
      solenoidOn[i] = lock_is_unlocked(i);
    } else {
      // Locker belum di-wire: kirim state default
      doorOpen[i] = false;
      solenoidOn[i] = false;
    }
  }

  // ============================================================
  // Kirim ke backend via /sync
  // ============================================================
  PollResult sync = backend_sync(doorOpen, solenoidOn);
  if (!sync.success)
    return;

  Serial.println("[Sync] OK");

  // ============================================================
  // Proses commands
  // ============================================================
  for (int i = 0; i < NUM_LOCKERS; i++) {
    if (sync.hasCommand[i]) {
      if (i < ACTIVE_LOCKERS) {
        Serial.printf("[Cmd] Locker %d: UNLOCK\n", i);
        lock_open(i);
        waitingForClose[i] = true;
      } else {
        Serial.printf("[Cmd] Locker %d: unlock (SKIP - belum di-wire)\n", i);
      }
    }
  }

  // ============================================================
  // Update token terbaru
  // ============================================================
  for (int i = 0; i < ACTIVE_LOCKERS; i++) {
    if (sync.qrTokens[i].length() > 0 &&
        sync.qrTokens[i] != lastRenderedToken[i]) {
      Serial.printf("[QR] Locker %d token: %s\n", i, sync.qrTokens[i].c_str());
      lastRenderedToken[i] = sync.qrTokens[i];
    }
  }

#if ENABLE_TFT
  // Round-robin: render 1 TFT per siklus sync
  {
    int idx = nextTftToRender;
    if (idx < ACTIVE_LOCKERS && lastRenderedToken[idx].length() > 0) {
      String lockerId = "locker_0" + String(idx + 1);
      tft_render_qr(idx, lockerId.c_str(), lastRenderedToken[idx].c_str());
    }
    nextTftToRender = (idx + 1) % ACTIVE_LOCKERS;
  }
#endif
}