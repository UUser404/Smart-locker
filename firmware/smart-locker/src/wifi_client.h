#ifndef WIFI_CLIENT_H
#define WIFI_CLIENT_H

#include <Arduino.h>
#include <WiFi.h>

// Inisialisasi WiFi + tunggu connect (blocking dengan timeout)
// Return true kalau berhasil, false kalau timeout
bool wifi_init();

// Cek koneksi; kalau putus, coba reconnect
// Return true kalau connected, false kalau tidak
bool wifi_check_and_reconnect();

// Dapatkan MAC address (string)
String wifi_get_mac();

#endif