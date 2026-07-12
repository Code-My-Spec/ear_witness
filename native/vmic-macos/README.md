# EarWitness Microphone — macOS virtual microphone

A virtual audio **input** device that meeting apps (Zoom / Teams / Meet) can
select as their microphone, and that EarWitness feeds. This is how a recording
notice (story 871) lands on the user's **outgoing** voice channel: EarWitness
plays the notice into the device, and remote participants hear it live.

## Mechanism: the loopback trick

The device is a Core Audio **AudioServerPlugIn** (HAL plug-in) derived from
[ExistentialAudio/BlackHole](https://github.com/ExistentialAudio/BlackHole) —
an open-source (GPL-3.0) virtual driver whose OUTPUT is internally wired to its
INPUT. So:

```
EarWitness  --play WAV-->  [ EarWitness Microphone OUTPUT ]
                                     | (internal loopback)
   Zoom mic  <--reads--  [ EarWitness Microphone INPUT ]
```

EarWitness plays audio to the device's output; the meeting app reads it from
the device's input. Zero custom IPC. We picked BlackHole (over building on
`gavv/libASPL` from scratch) because it *is* exactly this mechanism already,
builds from a single C file, and only needed build-time renaming — the fastest
route to a working device.

## Build

```bash
cd native/vmic-macos
./build.sh
```

Produces `build/EarWitnessMicrophone.driver`, a universal (arm64 + x86_64),
ad-hoc-signed `.driver` bundle. `build.sh` downloads the pinned BlackHole
source (cached under `vendor/`), compiles `BlackHole.c` with `clang` into a
CFBundle, applies the EarWitness identity via preprocessor constants
(`kDriver_Name`, `kPlugIn_BundleID`, `kDevice_Name`, `kNumber_Of_Channels=2`),
assembles the bundle, and codesigns it.

BlackHole's default `kSampleRates` list already includes 8 kHz / 16 kHz /
44.1 kHz / 48 kHz, so EarWitness's 16 kHz-mono WAVs play without extra config.

### xcodebuild alternative

BlackHole ships an Xcode project and its README documents the same
customization via `xcodebuild ... GCC_PREPROCESSOR_DEFINITIONS=...`. That path
is equivalent and also fine; `build.sh` uses `clang` directly because it has no
hard dependency on a working Xcode app install (the CI box this was validated
on had a broken Xcode simulator plug-in that made `xcodebuild` abort). Either
way the resulting bundle is signed the same way (below).

## Install / uninstall (machine-wide — run live with the user)

Installing is a **machine-wide** action: it copies the plug-in into a
root-owned system directory and restarts `coreaudiod`, which briefly
interrupts **all** audio on the machine. Do it deliberately.

```bash
sudo ./install.sh      # cp -R into /Library/Audio/Plug-Ins/HAL + killall coreaudiod
sudo ./uninstall.sh    # reverses it
```

The exact steps `install.sh` runs:

```bash
sudo cp -R build/EarWitnessMicrophone.driver /Library/Audio/Plug-Ins/HAL/
sudo killall coreaudiod
```

After install, "EarWitness Microphone" shows up in Audio MIDI Setup and as a
selectable mic/output in every app.

## Verify the round trip

With the driver installed:

```bash
mix run native/vmic-macos/verify.exs
```

Generates a 440 Hz tone, plays it into the device's output while capturing from
the device's input, and Goertzel-checks the tone survived the output → input
round trip. A pass proves audio injection works end to end.

## Feed path in EarWitness

- `EarWitness.Audio.Miniaudio.play_wav_to_device/2` — plays a WAV to the first
  playback device whose name contains a substring ("EarWitness Microphone").
- `EarWitness.Audio.Miniaudio.play_wav/1` — plays a WAV to the default output.
- `EarWitness.Audio.VirtualMic` — `available?/0`, `feed/1` / `play_notice/1`.
  This is the seam story 871 uses.

## Distribution: Developer ID + notarization REQUIRED

The build is **ad-hoc signed** (`codesign --sign -`), which is fine only on the
machine that built it. To ship EarWitness Microphone to other users' Macs you
**must**:

1. Code-sign the `.driver` with a **Developer ID Application** identity:
   ```bash
   CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" ./build.sh
   ```
2. **Notarize** the bundle (`xcrun notarytool submit ... --wait`) and staple it.

Without this, macOS Gatekeeper blocks the plug-in from loading on other
machines. HAL plug-ins are not sandboxed and load into `coreaudiod`, so Apple's
signing/notarization requirements apply strictly. This is a packaging task for
the desktop-distribution track, tracked separately from this build.

## License note

Derived from BlackHole, which is **GPL-3.0**. Redistributing the driver binary
carries GPL-3.0 obligations (offer of source, etc.). Flag for the licensing
review before shipping.
