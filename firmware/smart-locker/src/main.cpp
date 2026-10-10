#include "backend_poller.h"
#include "config.h"
#include "door_sensor.h"
#include "event_reporter.h"
#include "lock_control.h"
#include "tft_render.h"
#include "wifi_client.h"
#include <Arduino.h>

unsigned long lastPollMs = 0;
String lastRenderedToken[NUM_LOCKERS];
bool waitingForClose[NUM_LOCKERS] = {false};

// Set true untuk aktifkan TFT (biar bisa dimatikan saat hardware belum ada)
#define ENABLE_TFT true

void setup() {
  Serial.begin(115200);
  delay(1000);

  Serial.println();
  Serial.println("================================");
  Serial.println("Smart Locker Firmware v2.1");
  Serial.println("================================");

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

  for (int i = 0; i < NUM_LOCKERS; i++) {
    lastRenderedToken[i] = "";
    waitingForClose[i] = false;
  }

  Serial.println("[Sys] Setup selesai. Mulai polling.");
}

void loop() {
  if (!wifi_check_and_reconnect()) {
    delay(3000);
    return;
  }

  // Cek perubahan pintu
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

  // Poll backend
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

  // Proses QR token
  for (int i = 0; i < ACTIVE_LOCKERS; i++) {
    if (poll.qrTokens[i].length() > 0 &&
        poll.qrTokens[i] != lastRenderedToken[i]) {
      Serial.printf("[QR] Locker %d token: %s\n", i, poll.qrTokens[i].c_str());
      lastRenderedToken[i] = poll.qrTokens[i];

#if ENABLE_TFT
      // Render ke TFT: format "locker_01.9f3a1c"
      String lockerId = "locker_0" + String(i + 1);
      tft_render_qr(i, lockerId.c_str(), poll.qrTokens[i].c_str());
#endif
    }
  }
}