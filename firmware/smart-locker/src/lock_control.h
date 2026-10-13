#ifndef LOCK_CONTROL_H
#define LOCK_CONTROL_H

#include "config.h"
#include <Arduino.h>

// Inisialisasi pin relay
void lock_init();

// Buka solenoid locker idx (energize relay)
void lock_open(int idx);

// Kunci solenoid locker idx (de-energize relay)
void lock_lock(int idx);

// Cek apakah locker idx sedang dalam state unlocked
bool lock_is_unlocked(int idx);

#endif