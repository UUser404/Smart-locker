#ifndef EVENT_REPORTER_H
#define EVENT_REPORTER_H

#include <Arduino.h>

// Kirim POST /firmware/:controllerId/report ke backend
// event: "opened" atau "closed"
// Return true kalau berhasil (HTTP 200)
bool report_door_event(int lockerIndex, const char *event);

#endif