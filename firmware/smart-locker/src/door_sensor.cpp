#include "door_sensor.h"

// State terakhir per locker (untuk deteksi transisi)
static bool lastState[NUM_LOCKERS] = {false};
static unsigned long lastChangeMs[NUM_LOCKERS] = {0};

void door_init() {
  for (int i = 0; i < NUM_LOCKERS; i++) {
    pinMode(SENSOR_PINS[i], INPUT_PULLUP);
    lastState[i] = false;
    lastChangeMs[i] = 0;
  }
  Serial.println("[Door] Init selesai.");
}

bool door_is_open(int idx) {
  if (idx < 0 || idx >= NUM_LOCKERS)
    return false;
  // Sensor magnet/limit switch: LOW saat pintu tertutup (dengan pullup)
  // Jadi terbuka = HIGH
  int raw = digitalRead(SENSOR_PINS[idx]);
  return (raw == HIGH);
}

int door_check_transition(int idx) {
  if (idx < 0 || idx >= NUM_LOCKERS)
    return 0;

  bool current = door_is_open(idx);
  unsigned long now = millis();

  // Debounce
  if (current != lastState[idx]) {
    if (now - lastChangeMs[idx] < SENSOR_DEBOUNCE_MS) {
      return 0; // belum stabil
    }
    lastChangeMs[idx] = now;
    int result = current ? 1 : -1;
    lastState[idx] = current;
    return result;
  }
  return 0;
}