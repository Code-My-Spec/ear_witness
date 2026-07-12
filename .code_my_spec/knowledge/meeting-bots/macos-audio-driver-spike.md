# Audio driver spike — system-output TAP + virtual-mic INJECT (cross-platform)

Spike date: 2026-07-12. Author: native-macOS-audio spike agent.
Machine: macOS 26.3 (build 25D125), Xcode 26.5, Swift 6.3.2, Apple clang 21,
Apple Silicon (arm64).

This doc covers the two audio "driver path" problems that have repeatedly
blocked EarWitness, as **cross-platform** problems, and lands a concrete
architecture recommendation. Prototype effort focused on macOS because it is
the hard, blocking case; prototype code lives in the worktree at
`spikes/macos-audio/tap/` and `spikes/macos-audio/vmic/`.

The two mechanisms are **separate** and share almost no code:

- **TAP** = capture system audio **OUTPUT** (record the remote participant).
  Read-only; a *permission* problem. macOS is the only hole.
- **INJECT** = present a virtual **microphone** other apps read (put a
  recording-notice / mic+notice mix on the user's outgoing channel; story 871).
  Write side; a *signed-driver* problem on macOS and Windows.

---

## TL;DR for the product owner

- **"miniaudio isn't going to cut it" is correct — but only for two specific
  holes, not wholesale.** miniaudio already does mic capture on all three OSes
  and system-output loopback on Windows (WASAPI) + Linux (PulseAudio monitor).
  Its holes are exactly: (1) **macOS system-output capture** (no backend,
  issue #875) and (2) **creating a virtual mic on any OS** (miniaudio has no
  device-creation API at all). Those two holes are the whole job.
- **No single cross-platform library closes those holes.** Nothing creates a
  virtual mic on any OS, and macOS output-capture is native-only. cpal (Rust)
  is the only surveyed lib that even *wraps* macOS output capture — and it's
  Rust and still can't make a virtual device. Confirmed the prior.
- **Recommended architecture: keep the existing `capture_source` seam; keep
  miniaudio for what it's good at; add thin per-OS native modules only for the
  two holes.** Do **not** rip out miniaudio for a WebRTC/other monolith — it
  would not shrink the per-OS surface (you'd still hand-write the macOS tap and
  three virtual-mic drivers) and would cost a large rewrite.
- **The real cost is the INJECT direction: it means shipping a signed system
  driver per OS.** macOS = notarized userspace `.driver` (moderate). Windows =
  **kernel driver + EV cert + Microsoft attestation signing** (heavy). Linux =
  no driver at all, runtime PipeWire modules (trivial). Details in §5.
- **macOS TAP is feasible and mostly built** in this spike (see §2): tap +
  aggregate + format verified working on this machine; only the one-time user
  permission needs a human. Biggest open risk = that TCC permission UX + the
  macOS **14.4 floor** (14.6 if you lean on cpal/ScreenCaptureKit).

---

## 1. Per-OS mechanism table (BOTH directions)

### TAP — capture system audio output

| OS | Mechanism | Driver? | Permission | In miniaudio today? |
|----|-----------|---------|------------|---------------------|
| **macOS 14.4+** | Core Audio **process tap** (`AudioHardwareCreateProcessTap` + private aggregate device) | No (driverless) | TCC **"AudioCapture"** one-time prompt (purple dot) | **No — the hole.** Needs native module (built in this spike) |
| macOS 13–14.3 | **ScreenCaptureKit** audio (`SCStream` audio-only) | No | **Screen Recording** permission + menubar recording indicator | No |
| **Windows** | **WASAPI loopback** (`AUDCLNT_STREAMFLAGS_LOOPBACK`, miniaudio `ma_device_type_loopback`) | No | None | **Yes** (`start_loopback_capture/1`, Win path) |
| **Linux** | **PulseAudio/PipeWire monitor** source (`<sink>.monitor` opened as a capture device) | No | None | **Yes** (`find_linux_monitor_device`) |

Takeaway: **miniaudio's only capture hole is macOS.** Windows + Linux system
capture already work in `c_src/ear_witness/audio_capture.cpp` (though the ADR
notes Win/Linux loopback hasn't been exercised on real hardware/CI yet).

### INJECT — present a virtual microphone

| OS | Mechanism | Driver kind | Signing | In miniaudio? |
|----|-----------|-------------|---------|---------------|
| **macOS** | **AudioServerPlugIn** HAL plugin (BlackHole class) in `/Library/Audio/Plug-Ins/HAL/` | **Userspace** driver bundle, loaded by `coreaudiod` | Developer ID + **notarization**; sudo install; `killall coreaudiod` (no reboot) | **No** |
| **Windows** | Virtual audio **input** driver — WDM/PortCls "virtual audio cable" (VB-Cable / SysVAD class), or AVStream/APO | **Kernel-mode** driver | **EV code-signing cert + Microsoft Partner Center attestation signing** (Win10 1607+ won't load unsigned kernel drivers); reboot/PnP install | **No** |
| **Linux** | PipeWire/PulseAudio **null-sink + `module-remap-source`** (or a `libpipewire` virtual node) | **None** — runtime modules | None | **No** |

Takeaway: **miniaudio creates a virtual device on zero OSes** — it only
enumerates/opens existing devices. INJECT is entirely new native work on macOS
and Windows; Linux is config, not a driver.

---

## 2. macOS TAP — what I actually built and ran

Prototype: `spikes/macos-audio/tap/tap_probe.m` (+ `build.sh`, `README.md`).
A ~180-line Objective-C program: global process tap → private aggregate device
→ read tap format → IOProc → per-buffer RMS/peak + optional float32 WAV dump.

### API sequence (verified correct)
1. `CATapDescription initStereoGlobalTapButExcludeProcesses:@[]`; set
   `name`, `UUID`, `muteBehavior = CATapUnmuted`, `privateTap = YES`.
2. `AudioHardwareCreateProcessTap(desc, &tapID)`.
3. `AudioHardwareCreateAggregateDevice(props, &aggID)` where `props` sets
   `kAudioAggregateDeviceIsPrivateKey = YES`, `kAudioAggregateDeviceTapListKey
   = [{ kAudioSubTapUIDKey: <tap uuid>, kAudioSubTapDriftCompensationKey: YES }]`,
   `kAudioAggregateDeviceTapAutoStartKey = YES`, unique UID.
4. `AudioObjectGetPropertyData(tapID, kAudioTapPropertyFormat, …)` → ASBD.
5. `AudioDeviceCreateIOProcIDWithBlock(&proc, aggID, <serial queue>, block)`.
6. `AudioDeviceStart(aggID, proc)`; teardown reverses: Stop → DestroyIOProcID →
   DestroyAggregateDevice → DestroyProcessTap.

### Rigorously honest status
- **VERIFIED WORKING on this machine:** compile; `CreateProcessTap` (returned a
  live AudioObjectID); `CreateAggregateDevice` (private, tap in list); reading
  `kAudioTapPropertyFormat` → **48 kHz, 2 ch, 32-bit float** (flags 0x9).
- **BLOCKED ON A HUMAN (not a bug):** `AudioDeviceCreateIOProcIDWithBlock`
  triggers the **TCC "AudioCapture"** authorization. In this headless agent no
  one can click "Allow", so it blocks and no PCM flows. Service name confirmed
  via `tccutil reset AudioCapture` (succeeds). On an interactive Mac the user
  approves once and frames flow — the RMS log + WAV path are already wired, so a
  human running `./tap_probe 5 out.wav` after approving will get real audio.
- **RESEARCHED, NOT BUILT:** the ScreenCaptureKit 13+ fallback.

### Traps found the hard way (documented so the real impl doesn't re-hit them)
- **macOS 26: NULL dispatch queue = silent no-op.** Must pass a real serial
  queue to `AudioDeviceCreateIOProcIDWithBlock` or the IOProc never fires.
- **Leaked private aggregates collide.** A hard-killed run leaves its private
  aggregate in `coreaudiod`; reusing a fixed aggregate UID then fails
  (`AudioHardwareCreateAggregateDevice` → error `nope`). Use a per-run UID and
  always destroy on teardown.
- **`isExclusive` inverts include/exclude semantics** — trivially get "tap
  everything except X" vs "tap only X" backwards.
- **AVAudioEngine can't be retargeted** to a tap-backed aggregate (setter
  returns `noErr`, engine keeps reading default input). Use the raw
  `AudioDeviceCreateIOProcIDWithBlock` path (this prototype does).

### macOS version floor
- **14.4** for Core Audio process taps (API landed 14.2; 14.4 is the stable
  baseline everyone targets). cpal's CoreAudio loopback wants **14.6**.
- **13.0** if you fall back to ScreenCaptureKit audio — at the cost of the
  Screen-Recording permission + the always-visible menubar recording indicator,
  which is odd/heavy UX for a transcription tool. Recommend **14.4 floor,
  process tap primary; SCK only if telemetry shows a meaningful <14.4 install
  base**.

### Signing / entitlements for the tap
- Needs **`NSAudioCaptureUsageDescription`** in Info.plist (the prompt copy).
- Community reports: the TCC prompt keys on a **stable signing identity** —
  unsigned/ad-hoc builds may compile and even create the tap but fail to raise
  or persist the permission. Ship it inside the **Developer ID-signed,
  Hardened-Runtime, notarized** app bundle EarWitness already produces. One
  report disables App Sandbox (`com.apple.security.app-sandbox=false`) because
  "CATap under sandbox is fragile"; EarWitness is not a Mac App Store /
  sandboxed app today, so this is fine. No Mac App Store path validated.

---

## 3. Is there ONE cross-platform library that covers the hard parts?

Surveyed. **No.** Detail (what each does / does NOT do):

| Library | Mic capture | System-output capture | Create a virtual mic | Notes |
|---------|-------------|-----------------------|----------------------|-------|
| **miniaudio** (current) | ✅ all OS | ✅ Win/Linux, ❌ macOS (#875) | ❌ none | Single-header C, already integrated. |
| **cpal** (Rust) | ✅ | ✅ incl. **macOS** loopback (CoreAudio 14.6+) + a ScreenCaptureKit host | ❌ | Only surveyed lib wrapping macOS output capture — but **Rust**, foreign to our C++ NIF + Elixir stack, and still can't make a device. It just wraps the same native APIs my prototype calls. |
| **PortAudio** | ✅ | Partial WASAPI loopback on Win; ❌ macOS | ❌ | Thin host-API wrapper; no loopback abstraction, no device creation. |
| **RtAudio** | ✅ | ❌ | ❌ | Same class as PortAudio; no system capture, no virtual device. |
| **libsoundio** | ✅ | ❌ | ❌ | Similar, less active. |
| **libwebrtc `AudioDeviceModule`** | ✅ (selected device) | ❌ (no macOS output capture) | ❌ | ADM opens an existing device; APM does echo-cancel/NS. Not a system-capture or device-creation tool. |
| **JUCE** | ✅ | ❌ built-in | ❌ | App/framework wrapping host APIs; you'd still write the native tap + drivers yourself. Heavy dep for a headless Elixir app. |
| Commercial (Rogue Amoeba ACE, VB-Audio SDK, etc.) | — | some | some, **per-OS, licensed, still ship a driver** | No single-SDK cross-OS virtual-mic-creation exists; all are per-platform and still install a signed driver. |

Conclusion (confirms the prior): **macOS output-capture = native only; virtual
mic creation = native per-OS, no library does it anywhere.** A cross-platform
library buys you nothing for the two holes.

---

## 4. Architecture recommendation

**Keep the existing `capture_source` / `EarWitness.Audio.Pipeline` seam. Keep
miniaudio for its strengths. Add thin per-OS native modules for the two holes.
Do NOT replace miniaudio with a monolith.**

Rationale: the seam already exists and is honest about platform gaps —
`EarWitness.Audio.Miniaudio.loopback_available?/0` returns `false` on macOS,
`EarWitness.Audio.Tap.installed?/0` gates on it, and the pipeline is agnostic to
which backend produced PCM. miniaudio already nails mic (all OS) + system
loopback (Win/Linux). A WebRTC/JUCE rewrite would **not shrink the per-OS
surface** — you'd still hand-write the macOS tap and three virtual-mic drivers —
while adding a large migration and a heavier dependency. Net: negative trade.

### TAP holes → one macOS native module behind the seam
- New macOS-only native module (the `tap_probe.m` code, promoted to a NIF `.so`
  or a helper) that produces PCM exactly like the mic path does, converted to
  **16 kHz mono s16** to match `EarWitness.Recordings.WavHeader` and the
  transcription engine.
- Wiring: give `EarWitness.Audio.Miniaudio.start_loopback_capture/1` (or a
  sibling `EarWitness.Audio.MacTap`) a real macOS implementation instead of
  today's `{:error, :source_unavailable}`; make `loopback_available?/0` return
  `true` on macOS 14.4+. The rest of the app is unchanged.
- Build: the `Makefile` already links `-framework CoreAudio -framework
  AudioToolbox -framework CoreFoundation` for the audio NIF (see
  `AUDIO_LDFLAGS`), so the tap adds **no new frameworks** — add `CATapDescription`
  usage and, for the Obj-C bits, `-framework Foundation` + an `.m`/`.mm` file.
  Keep it a **separate `.so`** from whisper, as `audio_capture_nif` already is.

### INJECT holes → per-OS virtual-mic backend + a small "feed" seam
- macOS: ship a BlackHole-derived **AudioServerPlugIn** (`spikes/macos-audio/vmic/`).
  v1 uses the **loopback** trick (option (a)): user selects "EarWitness
  Microphone" as their mic; EarWitness plays the notice/mix into that device's
  **output** via the existing miniaudio playback path — **zero custom IPC**.
- Windows: a VB-Cable-class virtual input driver (biggest cost — §5).
- Linux: create the null-sink + `module-remap-source` at runtime (no driver).
- Common seam: a `virtual_mic` capability with `available?/0`, `install/0`
  (per-OS), and a `feed(pcm)`/"play notice" call. Mirrors how `capture_source`
  abstracts capture.

### Does the tap and the vmic share a native module?
Barely. Different APIs, different processes (the vmic is a *separate driver
bundle*, not in our address space; the tap runs *in* our process). Reasonable to
put both under one macOS native target for build tidiness, but they don't share
runtime code. Treat as two modules behind two seams (capture vs inject).

---

## 5. INJECT cost = shipping a signed system driver per OS (quantified)

This is the real burden. Per platform:

### macOS — moderate
- **Artifact:** userspace `.driver` (AudioServerPlugIn). No kext, no DriverKit,
  no reboot.
- **Signing:** Developer ID Application + Hardened Runtime; **notarize** the
  installer `.pkg`. Same Apple pipeline the app already uses → no new account
  capability, just a second signed artifact.
- **Install UX:** `sudo` copy into `/Library/Audio/Plug-Ins/HAL/` +
  `sudo killall -9 coreaudiod`. Rides in the app's privileged `.pkg` postinstall
  or a first-run admin helper. User re-picks the device / relaunches the meeting
  app once.
- **Effort:** start from BlackHole (compile-time name/channels) or **gavv/libASPL**
  (C++17, implements the property boilerplate — fits our toolchain). Days, not
  weeks, for option (a).

### Windows — heavy (the real tax)
- **Artifact:** **kernel-mode** WDM/PortCls audio driver (SysVAD/VB-Cable class).
- **Signing:** needs an **EV code-signing certificate**, a **Microsoft Partner
  Center (hardware dev) account**, and **attestation (or WHQL) signing** —
  Win10 1607+ refuses unsigned kernel drivers. This is a procurement + process
  cost (EV cert issuance, dashboard onboarding) beyond just "sign the binary."
- **Install UX:** driver-package (INF) install, PnP; may prompt/UAC; sometimes a
  reboot. Heavier than macOS.
- **Effort:** weeks + external signing bureaucracy. **This dominates the
  cross-platform virtual-mic budget** — plan around it (or buy a licensed
  VB-Audio-style SDK/driver and ship it signed).

### Linux — trivial
- **Artifact:** none. At runtime: `pactl load-module module-null-sink …` +
  `pactl load-module module-remap-source master=<sink>.monitor …`, or a
  `libpipewire` virtual node.
- **Signing/install:** none. Just create/tear down modules from the app.
- **Caveat:** must handle both PulseAudio and PipeWire; the remap-source can
  latch onto the wrong source and needs care/repair after login.

**Ordering suggestion:** macOS + Linux virtual mic first (cheap/moderate),
Windows kernel driver as its own budgeted workstream (or buy it).

---

## 6. Risks

- **TAP:** the TCC "AudioCapture" prompt UX + first-run guidance (ties to story
  861's guided-setup). Signing-identity sensitivity of the prompt. The 14.4
  floor as a distribution decision. Format conversion 48k f32 → 16k mono s16.
  Per-process tap PID resolution if we ever want "only the meeting app."
- **INJECT:** Windows kernel-driver signing bureaucracy (biggest). macOS install
  needing admin + coreaudiod restart mid-session. Loopback option (a) leaks any
  other audio played to that device (mitigate: only we target it). Linux
  Pulse-vs-PipeWire fragmentation. Ongoing OS-version breakage of an
  under-documented tap API (Apple changed NULL-queue behavior by macOS 26).
- **Cross-cutting:** two new signed native artifacts to maintain per OS release;
  notarization/signing added to CI for the driver bundle(s).

---

## 7. Prototype locations (in this worktree)

- `spikes/macos-audio/tap/tap_probe.m` — TAP prototype (compiles + runs; frames
  gated only by the user permission). `build.sh`, `README.md` alongside.
- `spikes/macos-audio/vmic/README.md` — INJECT mechanism, feed options, signing.
  `build_blackhole.sh` — the exact human build/install steps (not run here; the
  spike agent has no git access to clone/build a driver).

---

## 8. Sources (accessed 2026-07-12)

- Apple, "Capturing system audio with Core Audio taps" — https://developer.apple.com/documentation/CoreAudio/capturing-system-audio-with-core-audio-taps
- Apple, `AudioHardwareCreateProcessTap` — https://developer.apple.com/documentation/coreaudio/audiohardwarecreateprocesstap(_:_:)
- Apple, `AudioServerPlugInDriverInterface` — https://developer.apple.com/documentation/coreaudio/audioserverplugindriverinterface
- Apple, "Building an Audio Server Plug-in and Driver Extension" — https://developer.apple.com/documentation/coreaudio/building-an-audio-server-plug-in-and-driver-extension
- insidegui/AudioCap (macOS 14.4+ tap sample) — https://github.com/insidegui/AudioCap
- sudara, Core Audio Tap API example gist — https://gist.github.com/sudara/34f00efad69a7e8ceafa078ea0f76f6f
- "CoreAudio Taps for Dummies", maven.de (2025-04) — https://www.maven.de/2025/04/coreaudio-taps-for-dummies/
- DGR Labs, "Capturing System Audio on macOS in 2026" (2026-04-25) — https://dgrlabs.co/blog/2026-04-25-capturing-system-audio-on-macos-in-2026.html
- ExistentialAudio/BlackHole — https://github.com/ExistentialAudio/BlackHole
- gavv/libASPL (C++17 AudioServerPlugin lib) — https://github.com/gavv/libASPL
- kyleneideck/BackgroundMusic DEVELOPING.md — https://github.com/kyleneideck/BackgroundMusic/blob/master/DEVELOPING.md
- RustAudio/cpal (+ issue #876 ScreenCaptureKit loopback, macOS 14.6) — https://github.com/RustAudio/cpal
- Microsoft, SysVAD virtual audio driver sample — https://learn.microsoft.com/en-us/samples/microsoft/windows-driver-samples/sysvad-virtual-audio-device-driver-sample/
- Microsoft, Kernel-Mode Code Signing Requirements — https://learn.microsoft.com/en-us/windows-hardware/drivers/install/kernel-mode-code-signing-requirements--windows-vista-and-later-
- VirtualDrivers/Virtual-Audio-Driver (Win virtual speaker+mic) — https://github.com/VirtualDrivers/Virtual-Audio-Driver
- PipeWire Pulseaudio modules (null-sink / remap-source) — https://docs.pipewire.org/page_pulse_modules.html
- mackron/miniaudio#875 (no macOS loopback backend) — https://github.com/mackron/miniaudio/issues/875
