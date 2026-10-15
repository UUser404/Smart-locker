#include "door_sensor.h"

// State stabil (sudah lolos debounce) + kandidat state yang sedang diamati
static bool stableState[NUM_LOCKERS] = {false};
static bool candidateState[NUM_LOCKERS] = {false};
static unsigned long candidateSinceMs[NUM_LOCKERS] = {0};

static bool read_open_raw(int idx)
{
  // Wiring: pull-up eksternal 10k ke 3.3V, limit switch (terminal C + NO) ke GND.
  // Pintu tertutup = switch tertekan = LOW. Pintu terbuka = HIGH.
  return digitalRead(SENSOR_PINS[idx]) == HIGH;
}

void door_init()
{
  for (int i = 0; i < ACTIVE_LOCKERS; i++)
  {
    // GPIO 34/35/36/39 input-only dan TIDAK punya pull-up internal,
    // jadi pakai INPUT biasa; pull-up harus resistor eksternal.
    pinMode(SENSOR_PINS[i], INPUT);
    bool open = read_open_raw(i);
    stableState[i] = open; // mulai dari kondisi nyata, bukan asumsi "tertutup"
    candidateState[i] = open;
    candidateSinceMs[i] = millis();
  }
  Serial.println("[Door] Init selesai.");
}

bool door_is_open(int idx)
{
  if (idx < 0 || idx >= ACTIVE_LOCKERS)
    return false; // locker tidak aktif dianggap tertutup
  return read_open_raw(idx);
}

int door_check_transition(int idx)
{
  if (idx < 0 || idx >= ACTIVE_LOCKERS)
    return 0;

  bool current = read_open_raw(idx);
  unsigned long now = millis();

  // Pembacaan berubah: mulai hitung ulang masa stabil
  if (current != candidateState[idx])
  {
    candidateState[idx] = current;
    candidateSinceMs[idx] = now;
    return 0;
  }

  // Sudah stabil >= SENSOR_DEBOUNCE_MS dan beda dari state terakhir -> transisi
  if (current != stableState[idx] &&
      (now - candidateSinceMs[idx]) >= SENSOR_DEBOUNCE_MS)
  {
    stableState[idx] = current;
    return current ? 1 : -1; // 1 = baru terbuka, -1 = baru tertutup
  }
  return 0;
}