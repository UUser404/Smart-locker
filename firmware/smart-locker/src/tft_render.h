#ifndef TFT_RENDER_H
#define TFT_RENDER_H

#include <Arduino.h>

// Inisialisasi semua TFT (atau sebanyak ACTIVE_LOCKERS)
void tft_init();

// Render QR code untuk locker idx
// - url: string URL utuh dari backend (contoh:
// "https://www.locker-qu.com/locker_01?token=9f3a1c")
void tft_render_qr(int idx, const char *url);

// Tampilkan pesan teks (untuk status: "Locker tidak dapat dipakai" dll)
void tft_render_message(int idx, const char *line1, const char *line2);

// Clear layar locker idx
void tft_clear(int idx);

#endif