#ifndef TFT_RENDER_H
#define TFT_RENDER_H

#include <Arduino.h>

// Inisialisasi semua TFT (atau sebanyak ACTIVE_LOCKERS)
void tft_init();

// Render QR code untuk locker idx
// - lockerId: contoh "locker_01"
// - token: contoh "9f3a1c" (dari backend)
// Format QR yang dirender: "{lockerId}.{token}"
void tft_render_qr(int idx, const char *lockerId, const char *token);

// Tampilkan pesan teks (untuk status: "Locker tidak dapat dipakai" dll)
void tft_render_message(int idx, const char *line1, const char *line2);

// Clear layar locker idx
void tft_clear(int idx);

#endif