// C shim over Apple's private MultitouchSupport.framework.
// Everything is resolved at runtime with dlopen/dlsym (direct linking crashes on arm64e).
// Not thread-safe to call open/start/stop concurrently; call them from the main thread.
#pragma once
#include <stdint.h>

typedef struct { float x, y; } mt_point;  // millimetres from the trackpad's bottom-left corner

// Called once per touch frame (~90-125 Hz) on a private framework thread, with only the
// fingers currently touching the glass. count may be 0 (all fingers lifted).
typedef void (*mt_frame_cb)(const mt_point *touching, int count, double timestamp, void *ctx);

int mt_haptics_open(void);                  // open the built-in trackpad's actuator; 0 on success
void mt_haptics_close(void);                // close it (e.g. before reopening after wake); safe if not open
int mt_actuate(int32_t actuation_id);       // fire one pulse from any thread; 0 on success; nonzero if not open
int mt_touch_start(mt_frame_cb cb, void *ctx);  // start the touch stream; 0 on success
void mt_touch_stop(void);                   // stop the touch stream; safe if not started
