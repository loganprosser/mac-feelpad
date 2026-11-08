// Implementation of MTBridge.h. See the header for the contract.
//
// mt_haptics_open return codes: 0 ok, -2 framework or symbol missing, -3 no actuation-capable
// device, -4 actuator create failed, -5 actuator open failed (actuator's own nonzero code is lost).
// mt_touch_start return codes: 0 ok, -2 framework or symbol missing, -3 no default device.
#include "MTBridge.h"
#include <CoreFoundation/CoreFoundation.h>
#include <IOKit/IOKitLib.h>
#include <dlfcn.h>
#include <os/lock.h>
#include <stdatomic.h>
#include <stdbool.h>
#include <stddef.h>

typedef struct { float x, y; } MTPoint;
typedef struct { MTPoint pos, vel; } MTVector;
typedef struct {
    int frame; double timestamp; int identifier, state, fingerId, handId;
    MTVector normalized; float total, pressure, angle, majorAxis, minorAxis;
    MTVector absolute; int f14, f15; float density;
} MTTouch;  // layout from the working spike
typedef void (*FrameCB)(void *dev, MTTouch *t, int n, double ts, int frame);

static CFTypeRef (*ActCreate)(uint64_t);
static int (*ActOpen)(CFTypeRef), (*ActClose)(CFTypeRef), (*ActActuate)(CFTypeRef, int32_t, uint32_t, float, float);
static void *(*DevCreateDefault)(void);
static CFArrayRef (*DevCreateList)(void);
static bool (*DevIsBuiltIn)(void *);
static int (*DevSurfaceDims)(void *, int *, int *);
static void (*RegisterCB)(void *, FrameCB), (*UnregisterCB)(void *, FrameCB);
static void (*DevStart)(void *, int), (*DevStop)(void *), (*DevRelease)(void *);

static int loaded;  // 1 ok, -1 failed
static CFTypeRef act;  // guarded by act_lock: actuate runs on the touch thread, open/close on main
static os_unfair_lock act_lock = OS_UNFAIR_LOCK_INIT;
static void *dev;
static CFArrayRef dev_list;  // owns dev when it came from MTDeviceCreateList
static _Atomic(mt_frame_cb) user_cb;
static void *_Atomic user_ctx;
static float size_w = 120, size_h = 75;  // mm

static int load(void) {
    if (loaded) return loaded > 0 ? 0 : -2;
    loaded = -1;
    void *mt = dlopen("/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport", RTLD_NOW);
    if (!mt) return -2;
    ActCreate = dlsym(mt, "MTActuatorCreateFromDeviceID"); ActOpen = dlsym(mt, "MTActuatorOpen");
    ActClose = dlsym(mt, "MTActuatorClose");
    ActActuate = dlsym(mt, "MTActuatorActuate"); DevCreateDefault = dlsym(mt, "MTDeviceCreateDefault");
    DevCreateList = dlsym(mt, "MTDeviceCreateList"); DevIsBuiltIn = dlsym(mt, "MTDeviceIsBuiltIn");
    DevSurfaceDims = dlsym(mt, "MTDeviceGetSensorSurfaceDimensions");
    RegisterCB = dlsym(mt, "MTRegisterContactFrameCallback"); UnregisterCB = dlsym(mt, "MTUnregisterContactFrameCallback");
    DevStart = dlsym(mt, "MTDeviceStart"); DevStop = dlsym(mt, "MTDeviceStop"); DevRelease = dlsym(mt, "MTDeviceRelease");
    if (!ActCreate || !ActOpen || !ActClose || !ActActuate || !DevCreateDefault || !DevCreateList || !DevIsBuiltIn ||
        !DevSurfaceDims || !RegisterCB || !UnregisterCB || !DevStart || !DevStop || !DevRelease) return -2;
    loaded = 1;
    return 0;
}

static int prop_yes(io_service_t s, CFStringRef key) {
    CFTypeRef v = IORegistryEntryCreateCFProperty(s, key, NULL, 0);
    if (!v) return 0;
    int yes = 0;
    if (CFGetTypeID(v) == CFBooleanGetTypeID()) yes = CFBooleanGetValue(v);
    else if (CFGetTypeID(v) == CFNumberGetTypeID()) { int n = 0; CFNumberGetValue(v, kCFNumberIntType, &n); yes = n != 0; }
    CFRelease(v);
    return yes;
}

// Multitouch ID of the best actuation-capable device, or 0 if none.
static uint64_t find_device_id(void) {
    io_iterator_t it;
    if (IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("AppleMultitouchDevice"), &it)) return 0;
    uint64_t best = 0, first = 0;
    io_service_t s;
    while (!best && (s = IOIteratorNext(it))) {
        if (prop_yes(s, CFSTR("ActuationSupported"))) {
            CFTypeRef n = IORegistryEntryCreateCFProperty(s, CFSTR("Multitouch ID"), NULL, 0);
            uint64_t id = 0;
            if (n && CFGetTypeID(n) == CFNumberGetTypeID()) CFNumberGetValue(n, kCFNumberSInt64Type, &id);
            if (n) CFRelease(n);
            if (id) {
                if (prop_yes(s, CFSTR("MT Built-In"))) best = id;
                else if (!first) first = id;
            }
        }
        IOObjectRelease(s);
    }
    IOObjectRelease(it);
    return best ? best : first;
}

int mt_haptics_open(void) {
    if (act) return 0;
    if (load()) return -2;
    uint64_t id = find_device_id();
    if (!id) return -3;
    CFTypeRef a = ActCreate(id);
    if (!a) return -4;
    if (ActOpen(a)) { CFRelease(a); return -5; }
    os_unfair_lock_lock(&act_lock);
    act = a;
    os_unfair_lock_unlock(&act_lock);
    return 0;
}

void mt_haptics_close(void) {
    os_unfair_lock_lock(&act_lock);
    CFTypeRef a = act;
    act = NULL;
    os_unfair_lock_unlock(&act_lock);
    if (a) { ActClose(a); CFRelease(a); }
}

int mt_actuate(int32_t actuation_id) {
    os_unfair_lock_lock(&act_lock);
    int r = act ? ActActuate(act, actuation_id, 0, 0.0f, 0.0f) : -1;
    os_unfair_lock_unlock(&act_lock);
    return r;
}

// The built-in trackpad if there is one (the actuator prefers it too), else the system default.
static void *create_device(void) {
    CFArrayRef list = DevCreateList();
    for (CFIndex i = 0; list && i < CFArrayGetCount(list); i++) {
        void *d = (void *)CFArrayGetValueAtIndex(list, i);
        if (DevIsBuiltIn(d)) { dev_list = list; return d; }
    }
    if (list) CFRelease(list);
    return DevCreateDefault();
}

static void on_frame(void *d, MTTouch *t, int n, double ts, int frame) {
    (void)d; (void)frame;
    mt_frame_cb cb = user_cb;
    if (!cb) return;
    mt_point pts[16];
    int c = 0;
    for (int i = 0; i < n && c < 16; i++) {
        if (t[i].state != 4) continue;  // 4 = touching
        pts[c].x = t[i].normalized.pos.x * size_w;
        pts[c].y = t[i].normalized.pos.y * size_h;
        c++;
    }
    cb(pts, c, ts, user_ctx);
}

int mt_touch_start(mt_frame_cb cb, void *ctx) {
    if (dev) return 0;
    if (load()) return -2;
    void *d = create_device();
    if (!d) return -3;
    int w = 0, h = 0;
    if (DevSurfaceDims(d, &w, &h) == 0 && w > 0 && h > 0) { size_w = w / 100.0f; size_h = h / 100.0f; }
    else { size_w = 120; size_h = 75; }
    user_cb = cb; user_ctx = ctx;
    dev = d;
    RegisterCB(d, on_frame);
    DevStart(d, 0);
    return 0;
}

void mt_touch_stop(void) {
    if (!dev) return;
    UnregisterCB(dev, on_frame);
    DevStop(dev);
    if (dev_list) { CFRelease(dev_list); dev_list = NULL; }  // the list owns dev
    else DevRelease(dev);
    dev = NULL; user_cb = NULL; user_ctx = NULL;
}
