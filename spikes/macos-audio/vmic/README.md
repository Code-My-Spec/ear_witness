# INJECT spike — macOS virtual microphone (AudioServerPlugIn)

Goal: present an audio **input** device that other apps (Zoom/Teams/Meet) see
as a microphone, so EarWitness can put a recording-notice (or a mic+notice
mix) onto the user's outgoing voice channel. This is **story 871**.

## Status of this spike

- **Researched + source-understood.** NOT built here: this agent has **no git
  access**, so I could not `git clone` BlackHole or run `xcodebuild` in the
  worktree. The build/install steps below are transcribed from BlackHole's
  README and Apple's docs and must be run by a human on a real machine.
- A virtual mic is a **signed system driver**, not a CLI you can prove in an
  agent sandbox (unlike the TAP, which I *did* run — see `../tap/`).

## Mechanism: AudioServerPlugIn (the BlackHole class)

A macOS virtual audio device is an **AudioServerPlugIn** — a *userspace*
CoreAudio driver bundle (`.driver`) loaded by `coreaudiod`. No kernel
extension, no DriverKit, no kext approval. It lives at:

```
/Library/Audio/Plug-Ins/HAL/EarWitnessMic.driver
```

`coreaudiod` discovers plugins there at start. Installing or updating one
requires `sudo` (system path) and a `coreaudiod` restart:

```
sudo killall -9 coreaudiod   # or: sudo launchctl kickstart -k system/com.apple.audio.coreaudiod
```

No reboot is normally required (userspace), but audio apps already running
must be relaunched to see the new device.

### The plugin interface

The bundle exports a **factory function** (named in its `Info.plist`) that
returns an `AudioServerPlugInDriverInterface` — a struct of function pointers
the HAL calls. The ones that matter:

| Fn | Role |
|----|------|
| `Initialize` | driver startup, hand back the host reference |
| `CreateDevice` / `DestroyDevice` | device lifecycle (BlackHole publishes one static device, so these are mostly stubs) |
| `AddDeviceClient` | a process (Zoom) started using the device |
| `GetPropertyData` / `SetPropertyData` | answer the hundreds of CoreAudio property queries (name, UID, stream format, channel count, latency, …) — the bulk of the code |
| `StartIO` / `StopIO` | a client began/stopped pulling audio |
| `GetZeroTimeStamp` | the driver's clock — anchors the ring buffer timeline |
| `WillDoIOOperation` / `BeginIOOperation` / `DoIOOperation` / `EndIOOperation` | the **real-time** IO cycle |

`DoIOOperation` is the hot path. For `kAudioServerPlugInIOOperationReadInput`
(a client reading the mic) the driver copies frames **out of a ring buffer**
into the client's buffer. For `kAudioServerPlugInIOOperationWriteMix` (a client
writing to the output side) it copies frames **into** that ring buffer. That
input↔output ring buffer *is* the loopback: whatever is played to the device's
output stream reappears on its input stream. **Rule: never block, never
allocate, never lock in these callbacks.**

## Two ways to get EarWitness audio INTO the mic

**(a) Loopback + we play into it (least driver code — recommended for v1).**
Ship a BlackHole-style loopback device named "EarWitness Microphone". The user
picks it as their mic in Zoom. EarWitness opens that device's **output** side
(via the existing miniaudio playback path) and plays the notice / mic+notice
mix; the loopback carries it to the input side Zoom is reading. All the
cross-process plumbing is CoreAudio's own ring buffer — **we write zero IPC**.
Downside: anything else playing to that output device also leaks into the mic;
we mitigate by keeping the device private-ish and only we target it.

**(b) Custom driver that reads a shared ring buffer we own.** The `.driver`
`mmap`s a POSIX shared-memory segment (`shm_open`) that the EarWitness process
writes PCM into; `DoIOOperation`/ReadInput copies from it. More control (the
device is input-only, nothing else can inject) but we own an SPSC lock-free
ring buffer across a process boundary and a real-time reader — materially more
code and more ways to glitch. Defer past v1.

Start with (a).

## Building on it — don't hand-roll the plugin

Two C/C++ starting points (Apache/GPL — study for mechanism, mind licenses):

- **ExistentialAudio/BlackHole** — a single-file loopback driver. Channel
  count and names are compile-time `GCC_PREPROCESSOR_DEFINITIONS`
  (`kNumber_Of_Channels`, `kDriver_Name`, `kPlugIn_BundleID`, `kDevice_Name`).
  Closest to option (a). Ships `create_installer.sh` that builds + signs +
  notarizes a `.pkg`.
- **gavv/libASPL** — MIT-ish C++17 library that implements the property-query
  boilerplate so you subclass/configure instead of writing 2000 lines of
  `GetPropertyData`. Best base if we want option (b)'s custom input device and
  our own ring buffer. Fits EarWitness's existing C++ NIF toolchain.

See `build_blackhole.sh` for the exact human build/install steps.

## Signing / notarization / install burden (macOS)

- Bundle must be **Developer ID Application** signed (Hardened Runtime) and the
  installer `.pkg` **notarized** — same pipeline the app already uses for its
  notarized installers, so no *new* Apple account capability, but a second
  signed artifact.
- Install needs **admin (sudo)** to write `/Library/Audio/Plug-Ins/HAL/` and to
  `killall coreaudiod`. Practically this rides in the app's `.pkg` installer
  (a privileged install step / postinstall script), or a first-run helper.
- No kext approval, no reboot. Users must re-pick the device / relaunch the
  conferencing app once.
