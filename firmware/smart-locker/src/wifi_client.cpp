#include "wifi_client.h"
#include "config.h"

bool wifi_init() {
  Serial.print("[WiFi] Menghubungkan ke ");
  Serial.println(WIFI_SSID);

  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

  unsigned long start = millis();
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
    if (millis() - start > 30000) {
      Serial.println("\n[WiFi] Timeout 30s.");
      return false;
    }
  }

  Serial.println();
  Serial.print("[WiFi] Terhubung. IP: ");
  Serial.println(WiFi.localIP());
  return true;
}

bool wifi_check_and_reconnect() {
  if (WiFi.status() == WL_CONNECTED)
    return true;

  Serial.println("[WiFi] Terputus. Reconnect...");
  WiFi.reconnect();

  unsigned long start = millis();
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    if (millis() - start > 15000) {
      Serial.println("[WiFi] Reconnect gagal.");
      return false;
    }
  }
  Serial.println("[WiFi] Reconnect sukses.");
  return true;
}

String wifi_get_mac() { return WiFi.macAddress(); }