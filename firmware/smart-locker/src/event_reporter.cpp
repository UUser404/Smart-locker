#include "event_reporter.h"
#include "config.h"
#include <ArduinoJson.h>
#include <HTTPClient.h>
#include <WiFiClientSecure.h>

bool report_door_event(int lockerIndex, const char *event) {
  String url =
      String(BACKEND_BASE_URL) + "/firmware/" + CONTROLLER_ID + "/report";

  // Bangun payload
  JsonDocument doc;
  doc["locker_index"] = lockerIndex;
  doc["event"] = event;
  String payload;
  serializeJson(doc, payload);

  WiFiClientSecure client;
  client.setInsecure();
  client.setHandshakeTimeout(30);

  HTTPClient http;
  http.setTimeout(HTTP_TIMEOUT_MS);
  http.setReuse(false);

  if (!http.begin(client, url)) {
    Serial.println("[Report] Gagal init HTTP.");
    return false;
  }

  http.addHeader("Content-Type", "application/json");
  int httpCode = http.POST(payload);
  http.end();

  if (httpCode == 200) {
    Serial.printf("[Report] Locker %d event '%s' terkirim.\n", lockerIndex,
                  event);
    return true;
  }

  Serial.printf("[Report] Gagal kirim: HTTP %d\n", httpCode);
  return false;
}