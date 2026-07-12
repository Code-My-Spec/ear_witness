# TAP spike — macOS system-audio OUTPUT capture (Core Audio process taps)

Captures "the other side of the call" (remote participant's voice out of the
speakers) driverlessly on macOS 14.4+. This is the modern replacement for the
BlackHole/loopback hack for the *capture* direction.

## Files
- `tap_probe.m` — minimal Obj-C: creates a global process tap, a private
  aggregate device, reads the tap format, installs an IOProc, prints per-buffer
  RMS/peak and optionally dumps a float32 WAV.
- `build.sh` — `clang -framework CoreAudio -framework AudioToolbox` + ad-hoc sign.

## Run
```
sh build.sh
./tap_probe 5 out.wav      # capture 5s, dump WAV; play audio while it runs
```

## What was VERIFIED on this machine (macOS 26.3, Xcode 26.5)
- Compiles clean against the 14.4+ SDK.
- `AudioHardwareCreateProcessTap` → **succeeds** (real tap AudioObjectID).
- `AudioHardwareCreateAggregateDevice` (private, tap in `kAudioAggregateDeviceTapListKey`)
  → **succeeds**.
- `kAudioTapPropertyFormat` → **48000 Hz, 2 ch, 32-bit float** (flags 0x9 =
  float|packed). The tap's real format; downstream must convert to EarWitness's
  16 kHz mono s16.

## What needs a HUMAN (the boundary)
- `AudioDeviceCreateIOProcIDWithBlock` / `AudioDeviceStart` trigger the **TCC
  "AudioCapture"** authorization. In this headless agent there is no one to
  click "Allow", so the call **blocks** and no frames flow. Confirmed the
  service name via `tccutil reset AudioCapture` (succeeds). In an interactive
  session the user approves once (a purple dot, not the mic orange dot) and
  frames flow; the WAV dump path is already wired.

## Gotchas baked into the code (all real, all cost hours if missed)
- **macOS 26 needs a non-NULL dispatch queue** on
  `AudioDeviceCreateIOProcIDWithBlock` — passing NULL silently never fires the
  IOProc. Fixed: we pass a serial queue.
- **Unique aggregate UID per run** — a hard-killed run leaks its private
  aggregate in `coreaudiod`; reusing a fixed UID then fails with a collision
  (`AudioHardwareCreateAggregateDevice` → error `nope`). Fixed: UID includes pid.
- **Global vs per-process**: `initStereoGlobalTapButExcludeProcesses:@[]` taps
  everything. For per-process (only the Zoom PID) use
  `initWithProcesses:andDeviceUID:withStream:`. `isExclusive` inverts include
  vs exclude semantics — easy to get backwards.
