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
String lastRenderedToken[NUM_LOCKERS]; // token terbaru dari backend
String lastDrawnToken[NUM_LOCKERS];    // token yang sudah tergambar di TFT
bool waitingForClose[NUM_LOCKERS] = {false};
bool doorSeenOpen[NUM_LOCKERS] = {false};
unsigned long unlockedAtMs[NUM_LOCKERS] = {0};

// Backend mendeteksi pintu hanya dari nilai door_open tiap /sync. Kalau pintu
// dibuka lalu ditutup di antara dua sync, backend tidak melihat transisinya.
// openLatch memastikan "pernah terbuka" tetap terlapor di sync berikutnya.
bool openLatch[NUM_LOCKERS] = {false};
bool forceSync = false; // sync segera saat pintu berubah, tanpa tunggu interval

// Batas maksimal solenoid dialiri arus (relay ON) sejak perintah unlock.
// Solenoid 12V tidak dirancang menyala terus; setelah waktu ini dikunci lagi.
#ifndef UNLOCK_HOLD_MS
#define UNLOCK_HOLD_MS 10000
#endif

// Round-robin TFT update: index yang dicek lebih dulu pada siklus berikutnya
int nextTftToRender = 0;

// ============================================================
// SETUP
// ============================================================
void setup()
{
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

  // Pastikan semua relay OFF (terkunci) sebelum urusan WiFi yang bisa lama
  lock_init();

  Serial.print("[Sys] MAC Address: ");
  Serial.println(wifi_get_mac());

  if (!wifi_init())
  {
    Serial.println("[Sys] WiFi gagal. Restart...");
    delay(3000);
    ESP.restart();
  }

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

  for (int i = 0; i < NUM_LOCKERS; i++)
  {
    lastRenderedToken[i] = "";
    lastDrawnToken[i] = "";
    waitingForClose[i] = false;
  }

  Serial.println("[Sys] Setup selesai. Mulai sync.");
}

// ============================================================
// LOOP
// ============================================================
void loop()
{
  // Reset watchdog setiap loop
  esp_task_wdt_reset();

  // ============================================================
  // Auto-lock: jalan tiap loop, tidak menunggu interval sync / WiFi.
  // Kunci lagi kalau (a) pintu sudah terbuka lalu tertutup (debounced),
  // atau (b) UNLOCK_HOLD_MS habis (pintu tidak dibuka / terlalu lama).
  // ============================================================
  for (int i = 0; i < ACTIVE_LOCKERS; i++)
  {
#if ENABLE_DOOR_SENSOR
    int t = door_check_transition(i); // harus dipanggil tiap loop untuk debounce
#else
    int t = 0;
#endif
    if (t == 1)
      openLatch[i] = true;
    if (t != 0)
      forceSync = true;

    if (!waitingForClose[i])
      continue;

    if (t == 1)
      doorSeenOpen[i] = true;

    bool relock = false;
    if (t == -1 && doorSeenOpen[i])
    {
      Serial.printf("[Lock] Locker %d: pintu tertutup -> kunci\n", i);
      relock = true;
    }
    else if (millis() - unlockedAtMs[i] >= UNLOCK_HOLD_MS)
    {
      Serial.printf("[Lock] Locker %d: batas %d ms habis -> kunci\n", i,
                    UNLOCK_HOLD_MS);
      relock = true;
    }

    if (relock)
    {
      lock_lock(i);
      waitingForClose[i] = false;
    }
  }

  if (!wifi_check_and_reconnect())
  {
    delay(3000);
    return;
  }

  // Sync backend tiap POLL_INTERVAL_MS
  if (!forceSync && millis() - lastPollMs < POLL_INTERVAL_MS)
    return;
  forceSync = false;
  lastPollMs = millis();

  digitalWrite(STATUS_LED_PIN, !digitalRead(STATUS_LED_PIN));

  // ============================================================
  // Baca state pintu + solenoid semua locker
  // ============================================================
  bool doorOpen[NUM_LOCKERS] = {false};
  bool solenoidOn[NUM_LOCKERS] = {false};

  for (int i = 0; i < NUM_LOCKERS; i++)
  {
    if (i < ACTIVE_LOCKERS)
    {
#if ENABLE_DOOR_SENSOR
      doorOpen[i] = door_is_open(i) || openLatch[i];
#else
      // Dev mode: pin floating, kirim false supaya backend tidak deteksi
      // transisi palsu
      doorOpen[i] = false;
#endif
      solenoidOn[i] = lock_is_unlocked(i);
    }
    else
    {
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

  // Backend sudah menerima door_open=true; sync berikutnya akan melaporkan
  // kondisi nyata (tertutup), sehingga backend melihat transisi open -> closed.
  for (int i = 0; i < NUM_LOCKERS; i++)
    openLatch[i] = false;

  Serial.println("[Sync] OK");

  // ============================================================
  // Proses commands
  // ============================================================
  for (int i = 0; i < NUM_LOCKERS; i++)
  {
    if (sync.hasCommand[i])
    {
      if (i < ACTIVE_LOCKERS)
      {
        Serial.printf("[Cmd] Locker %d: UNLOCK\n", i);
        lock_open(i);
        waitingForClose[i] = true;
        unlockedAtMs[i] = millis();
#if ENABLE_DOOR_SENSOR
        doorSeenOpen[i] = door_is_open(i); // kalau sudah terbuka, tunggu tutup
#else
        doorSeenOpen[i] = false;
#endif
      }
      else
      {
        Serial.printf("[Cmd] Locker %d: unlock (SKIP - belum di-wire)\n", i);
      }
    }
  }

  // ============================================================
  // Update token terbaru
  // ============================================================
  for (int i = 0; i < ACTIVE_LOCKERS; i++)
  {
    if (sync.qrTokens[i].length() > 0 &&
        sync.qrTokens[i] != lastRenderedToken[i])
    {
      Serial.printf("[QR] Locker %d token: %s\n", i, sync.qrTokens[i].c_str());
      lastRenderedToken[i] = sync.qrTokens[i];
    }
  }

#if ENABLE_TFT
  // Gambar ulang HANYA kalau token berubah (hindari flicker),
  // maksimal 1 TFT per siklus sync supaya loop tidak lama terblokir.
  for (int n = 0; n < ACTIVE_LOCKERS; n++)
  {
    int idx = (nextTftToRender + n) % ACTIVE_LOCKERS;
    if (lastRenderedToken[idx].length() > 0 &&
        lastRenderedToken[idx] != lastDrawnToken[idx])
    {
      String lockerId = "locker_0" + String(idx + 1);
      tft_render_qr(idx, lockerId.c_str(), lastRenderedToken[idx].c_str());
      lastDrawnToken[idx] = lastRenderedToken[idx];
      nextTftToRender = (idx + 1) % ACTIVE_LOCKERS;
      break;
    }
  }
#endif
}