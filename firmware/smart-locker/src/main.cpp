#include <Arduino.h>
#include <WiFi.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>

// Ganti dengan SSID WiFi Anda (pastikan tidak ada password atau kosongkan jika terbuka)
const char *ssid = "Ruang Kuliah 01";
const char *password = "";

// Menggunakan protokol http:// agar kompatibel dengan pembatasan SSL di server gratis Render
const char *backendPollUrl = "http://smart-locker-backend-a2ck.onrender.com/api/firmware/esp32_01/poll";

void setup()
{
  Serial.begin(115200);
  delay(1000);

  WiFi.begin(ssid, password);

  Serial.print("Menghubungkan ke WiFi");
  while (WiFi.status() != WL_CONNECTED)
  {
    delay(500);
    Serial.print(".");
  }
  Serial.println("\nWiFi terhubung!");
}

void loop()
{
  if (WiFi.status() == WL_CONNECTED)
  {
    WiFiClient client;
    HTTPClient http;

    // Mulai koneksi HTTP GET ke endpoint backend
    if (http.begin(client, backendPollUrl))
    {
      int httpResponseCode = http.GET();

      if (httpResponseCode > 0)
      {
        String payload = http.getString();
        Serial.print("HTTP Response code: ");
        Serial.println(httpResponseCode);
        Serial.println("Respon Server: " + payload);
      }
      else
      {
        Serial.print("Error code: ");
        Serial.println(httpResponseCode);
      }
      http.end();
    }
    else
    {
      Serial.println("Gagal menginisialisasi HTTP connection");
    }
  }
  else
  {
    Serial.println("WiFi terputus, mencoba menghubungkan kembali...");
    WiFi.reconnect();
  }

  delay(5000); // Polling setiap 5 detik
}