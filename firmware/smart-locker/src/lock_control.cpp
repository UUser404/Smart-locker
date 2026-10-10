#include "lock_control.h"

// State internal
static bool unlockedState[NUM_LOCKERS] = {false};

void lock_init() {
  for (int i = 0; i < NUM_LOCKERS; i++) {
    pinMode(RELAY_PINS[i], OUTPUT);
    digitalWrite(RELAY_PINS[i], HIGH); // relay OFF (aktif LOW)
    unlockedState[i] = false;
  }
  Serial.println("[Lock] Init selesai.");
}

void lock_open(int idx) {
  if (idx < 0 || idx >= NUM_LOCKERS)
    return;
  Serial.printf("[Lock] Buka locker %d\n", idx);
  digitalWrite(RELAY_PINS[idx], LOW); // aktif LOW = relay ON
  unlockedState[idx] = true;
}

void lock_lock(int idx) {
  if (idx < 0 || idx >= NUM_LOCKERS)
    return;
  Serial.printf("[Lock] Kunci locker %d\n", idx);
  digitalWrite(RELAY_PINS[idx], HIGH); // aktif LOW = relay OFF
  unlockedState[idx] = false;
}

bool lock_is_unlocked(int idx) {
  if (idx < 0 || idx >= NUM_LOCKERS)
    return false;
  return unlockedState[idx];
}