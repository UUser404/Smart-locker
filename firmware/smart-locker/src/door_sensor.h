#ifndef DOOR_SENSOR_H
#define DOOR_SENSOR_H

#include "config.h"
#include <Arduino.h>

// Inisialisasi pin sensor
void door_init();

// Baca raw state: true kalau pintu terbuka
bool door_is_open(int idx);

// Cek perubahan state sejak panggilan terakhir
// Return: 0 = tidak ada perubahan, 1 = baru buka, -1 = baru tutup
int door_check_transition(int idx);

#endif