#include "backend_poller.h"
#include "config.h"
#include <HTTPClient.h>
#include <WiFiClientSecure.h>

PollResult backend_poll(const char *url_override) {
  PollResult result;
  result.success = false;
  result.httpCode = -1;
  for (int i = 0; i < NUM_LOCKERS; i++) {
    result.hasCommand[i] = false;
    result.qrTokens[i] = "";
  }

  // Bangun URL
  String url;
  if (url_override) {
    url = String(url_override);
  } else {
    url = String(BACKEND_BASE_URL) + "/firmware/" + CONTROLLER_ID + "/poll";
  }

  WiFiClientSecure client;
  client.setInsecure();
  client.setHandshakeTimeout(30);

  HTTPClient http;
  http.setTimeout(HTTP_TIMEOUT_MS);
  http.setReuse(false);

  if (!http.begin(client, url)) {
    Serial.println("[Poll] Gagal init HTTP.");
    return result;
  }

  int httpCode = http.GET();
  result.httpCode = httpCode;

  if (httpCode != 200) {
    if (httpCode > 0) {
      Serial.printf("[Poll] HTTP %d: %s\n", httpCode, http.getString().c_str());
    } else {
      Serial.printf("[Poll] Error: %s\n", http.errorToString(httpCode).c_str());
    }
    http.end();
    return result;
  }

  String payload = http.getString();
  http.end();

  // Parse JSON
  JsonDocument doc;
  DeserializationError err = deserializeJson(doc, payload);
  if (err) {
    Serial.printf("[Poll] JSON parse error: %s\n", err.c_str());
    return result;
  }

  // Parse commands
  JsonArray cmds = doc["commands"].as<JsonArray>();
  for (JsonObject cmd : cmds) {
    int idx = cmd["locker_index"] | -1;
    if (idx >= 0 && idx < NUM_LOCKERS) {
      result.hasCommand[idx] = true;
    }
  }

  // Parse qr_tokens
  JsonObject tokens = doc["qr_tokens"].as<JsonObject>();
  for (int i = 0; i < NUM_LOCKERS; i++) {
    String key = String(i);
    if (tokens[key].is<const char *>()) {
      result.qrTokens[i] = tokens[key].as<const char *>();
    } else {
      result.qrTokens[i] = "";
    }
  }

  result.success = true;
  return result;
}