// C interface to the macOS Core Audio process-tap capture backend
// (mac_tap.mm). The miniaudio capture NIF (audio_capture.cpp) calls these from
// its `#ifdef __APPLE__` loopback paths so system-output ("what you hear")
// capture works on macOS 14.4+, which miniaudio itself has no backend for
// (mackron/miniaudio#875). See the macos-system-audio-tap ADR.
//
// Extern "C" so the ObjC++ implementation links against the C++ NIF without
// name mangling.

#ifndef EAR_WITNESS_MAC_TAP_H
#define EAR_WITNESS_MAC_TAP_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// Starts a system-output process tap capturing to a growing 16kHz-mono-s16
// buffer. Returns an opaque handle on success, or NULL if the tap couldn't be
// created/started (e.g. below the macOS floor, or the TCC AudioCapture
// permission was denied). The handle must be passed to exactly one of
// ew_mac_tap_stop (finalizes the WAV) or ew_mac_tap_free (discards).
void *ew_mac_tap_start(const char *path);

// Stops the tap, converts+writes the accumulated samples to the path given at
// start as a 16kHz mono PCM16 WAV, tears down the Core Audio objects, and
// frees the handle. Returns 0 on success, -1 if the WAV write failed (the
// handle is still torn down and freed either way).
int ew_mac_tap_stop(void *handle);

// Copies the samples accumulated since the last read out of the tap's buffer
// into a freshly malloc'd array (16kHz mono s16, little-endian) which the
// caller takes ownership of and must free(). *out_count is the number of
// int16 samples — 0 (with *out_samples left NULL) when nothing new has
// arrived. Returns true on success. Lets the live transcriber drain an
// in-progress tap capture the same way capture_read_new/1 drains a miniaudio
// one; safe to call any time between start and stop.
bool ew_mac_tap_read_new(void *handle, int16_t **out_samples, size_t *out_count);

// Tears down the Core Audio objects and frees the handle WITHOUT writing a
// WAV — the discard path (used by the resource destructor if a capture is
// garbage-collected without an explicit stop, so the private aggregate device
// never leaks into coreaudiod).
void ew_mac_tap_free(void *handle);

// Whether system-output tap capture is available on this machine — true on
// macOS 14.4+ (Core Audio process taps), false below that floor.
bool ew_mac_tap_available(void);

#ifdef __cplusplus
}
#endif

#endif  // EAR_WITNESS_MAC_TAP_H
