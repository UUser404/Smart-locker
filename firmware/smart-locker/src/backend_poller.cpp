#include "backend_poller.h"
#include "config.h"
#include <HTTPClient.h>
#include <WiFiClientSecure.h>

PollResult backend_sync(const bool doorOpen[NUM_LOCKERS],
                        const bool solenoidOn[NUM_LOCKERS]) {
  PollResult result;
  result.success = false;
  result.httpCode = -1;
  for (int i = 0; i < NUM_LOCKERS; i++) {
    result.hasCommand[i] = false;
    result.qrTokens[i] = "";
  }

  // Build URL
  String url =
      String(BACKEND_BASE_URL) + "/firmware/" + CONTROLLER_ID + "/sync";

  // Build body
  JsonDocument doc;
  JsonArray arr = doc["lockers"].to<JsonArray>();
  for (int i = 0; i < ACTIVE_LOCKERS; i++) {
    JsonObject o = arr.add<JsonObject>();
    o["index"] = i;
    o["door_open"] = doorOpen[i];
    o["solenoid_on"] = solenoidOn[i];
  }
  String payload;
  serializeJson(doc, payload);

  // HTTPS
  WiFiClientSecure client;
  client.setInsecure();
  client.setHandshakeTimeout(30);

  HTTPClient http;
  http.setTimeout(HTTP_TIMEOUT_MS);
  http.setReuse(false);

  if (!http.begin(client, url)) {
    Serial.println("[Sync] Gagal init HTTP.");
    return result;
  }

  http.addHeader("X-Device-Token", DEVICE_TOKEN);
  http.addHeader("Content-Type", "application/json");

  int httpCode = http.POST(payload);
  result.httpCode = httpCode;

  if (httpCode != 200) {
    if (httpCode > 0) {
      Serial.printf("[Sync] HTTP %d: %s\n", httpCode, http.getString().c_str());
    } else {
      Serial.printf("[Sync] Error: %s\n", http.errorToString(httpCode).c_str());
    }
    http.end();
    return result;
  }

  String response = http.getString();
  http.end();

  JsonDocument respDoc;
  DeserializationError err = deserializeJson(respDoc, response);
  if (err) {
    Serial.printf("[Sync] JSON parse error: %s\n", err.c_str());
    return result;
  }

  // Parse commands
  JsonArray cmds = respDoc["commands"].as<JsonArray>();
  for (JsonObject cmd : cmds) {
    int idx = cmd["locker_index"] | -1;
    if (idx >= 0 && idx < NUM_LOCKERS) {
      result.hasCommand[idx] = true;
    }
  }

  // Parse qr_tokens
  JsonObject tokens = respDoc["qr_tokens"].as<JsonObject>();
  for (int i = 0; i < NUM_LOCKERS; i++) {
    String key = String(i);
    if (tokens[key].is<const char *>()) {
      result.qrTokens[i] = tokens[key].as<const char *>();
    }
  }

  result.success = true;
  return result;
}