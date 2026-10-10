#include "backend_poller.h"
#include "config.h"
#include "door_sensor.h"
#include "event_reporter.h"
#include "lock_control.h"
#include "tft_render.h"
#include "wifi_client.h"
#include <Arduino.h>
#include <esp_task_wdt.h>

unsigned long lastPollMs = 0;
String lastRenderedToken[NUM_LOCKERS];
bool waitingForClose[NUM_LOCKERS] = {false};

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
  Serial.println("Smart Locker Firmware v3.0");
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
  door_init();

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

  Serial.println("[Sys] Setup selesai. Mulai polling.");
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

  // Cek perubahan pintu untuk semua locker yang aktif
  for (int i = 0; i < ACTIVE_LOCKERS; i++) {
    int transition = door_check_transition(i);
    if (transition == 1) {
      Serial.printf("[Door] Locker %d: pintu terbuka\n", i);
    } else if (transition == -1) {
      Serial.printf("[Door] Locker %d: pintu tertutup\n", i);
      lock_lock(i);
      report_door_event(i, "closed");
      waitingForClose[i] = false;
    }
  }

  // Poll backend tiap POLL_INTERVAL_MS
  if (millis() - lastPollMs < POLL_INTERVAL_MS)
    return;
  lastPollMs = millis();

  digitalWrite(STATUS_LED_PIN, !digitalRead(STATUS_LED_PIN));

  PollResult poll = backend_poll();
  if (!poll.success)
    return;

  Serial.println("[Poll] OK");

  // Proses commands
  for (int i = 0; i < NUM_LOCKERS; i++) {
    if (poll.hasCommand[i]) {
      if (i < ACTIVE_LOCKERS) {
        Serial.printf("[Cmd] Locker %d: UNLOCK\n", i);
        lock_open(i);
        waitingForClose[i] = true;
      } else {
        Serial.printf("[Cmd] Locker %d: unlock (SKIP - belum di-wire)\n", i);
      }
    }
  }

  // Simpan token terbaru ke cache (tidak langsung render)
  for (int i = 0; i < ACTIVE_LOCKERS; i++) {
    if (poll.qrTokens[i].length() > 0 &&
        poll.qrTokens[i] != lastRenderedToken[i]) {
      Serial.printf("[QR] Locker %d token: %s\n", i, poll.qrTokens[i].c_str());
      lastRenderedToken[i] = poll.qrTokens[i];
    }
  }

#if ENABLE_TFT
  // Round-robin: render 1 TFT per siklus poll
  // Kalau token locker ini berbeda dari yang sudah dirender, update.
  {
    int idx = nextTftToRender;
    if (idx < ACTIVE_LOCKERS && lastRenderedToken[idx].length() > 0) {
      // Hanya render kalau benar-benar berubah — hindari redraw berulang
      String lockerId = "locker_0" + String(idx + 1);
      tft_render_qr(idx, lockerId.c_str(), lastRenderedToken[idx].c_str());
    }
    nextTftToRender = (idx + 1) % ACTIVE_LOCKERS;
  }
#endif
}