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

PollResult backend_poll(const char *url_override = nullptr);

#endif