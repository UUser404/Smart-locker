#ifndef BACKEND_POLLER_H
#define BACKEND_POLLER_H

#include "config.h"
#include <Arduino.h>
#include <ArduinoJson.h>

struct PollResult {
  bool success;
  int httpCode;
  bool hasCommand[NUM_LOCKERS];
  String qrTokens[NUM_LOCKERS];
};

// Kirim state locker + terima commands + qr_tokens
// lockers: array state per locker (door_open, solenoid_on)
PollResult backend_sync(const bool doorOpen[NUM_LOCKERS],
                        const bool solenoidOn[NUM_LOCKERS]);

#endif