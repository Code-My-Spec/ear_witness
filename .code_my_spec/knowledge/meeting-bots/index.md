# Meeting-bot techniques — synthesis for the `meeting-bot-relay` ADR

Research date: **2026-07-12**. Feeds `.code_my_spec/architecture/decisions/meeting-bot-relay.md` (status: Proposed, no vendor chosen). Four detail files back this up:

- [zoom.md](zoom.md) · [microsoft-teams.md](microsoft-teams.md) · [google-meet.md](google-meet.md) · [landscape-and-vendors.md](landscape-and-vendors.md)

Context: EarWitness is a **local-first, privacy-focused Elixir desktop** transcription app. It must capture both sides of a meeting and transcribe **on-device**. The question is how the audio gets in.

---

## The one decision that dominates everything

> **Do we need to capture meetings the user is NOT physically attending on their own machine?**

- **No** → **on-device system-audio capture wins** on privacy, robustness, and cost, and the entire "relay" question mostly dissolves. No bot, no vendor, no per-platform arms race.
- **Yes** → you are forced into a **bot**, and then the only real choice is **self-hosted (private, you run infra)** vs. **hosted (turnkey, audio leaves the device)**. There is **no turnkey + bot + audio-stays-on-device** option. That's the irreducible tension.

Every agent independently converged on this: **bot-vs-no-bot matters more than which vendor.**

---

## Two axes

| | **Runs locally (audio stays on device)** | **Requires cloud / third-party** |
|---|---|---|
| **No bot** (capture what plays on this machine) | ✅ **System-audio capture** — universal, all platforms | — |
| **Bot** (joins the call as a participant) | ⚠️ Only sometimes: Zoom Meeting SDK ✅; Meet browser-automation ✅ (fragile); Meet Media API 🔜 (preview); **Teams ❌** | Recall.ai (turnkey), self-hosted Vexa/Attendee (private but you host) |

---

## Per-provider feasibility (can a *local* bot capture live audio?)

| Provider | Local join-bot? | Audio quality | Notes |
|---|---|---|---|
| **Zoom** | ✅ **Meeting SDK bot** (native Win/mac/Linux, via OS-process port) | **Per-speaker** raw PCM | Best join-bot case. Verify headless-macOS + whether own-account use avoids full Marketplace review. RTMS (GA 2025-06) is real-time but **cloud-only**. |
| **Teams** | ❌ **None** | — | Official Graph media bot is structurally cloud + Windows/C# + tenant admin; no Python/REST/WS path as of 2026. Teams now auto-flags assistant bots in the lobby (MC1251206, mid-2026). |
| **Meet** | ⚠️ **Browser automation** (headless Chromium + virtual audio device) | Mixed | Only live-capture path today; fragile to UI changes; visible bot. **Meet Media API** (real-time, no visible participant, could run locally) is the future but **Developer Preview**, gated behind all-participant enrollment. |
| **All three** | ✅ **System-audio capture (no bot)** | Mixed (far side) | Uniform across platforms. macOS Core Audio tap / Windows WASAPI loopback / Linux monitor — **already EarWitness's direction** (story 861, `macos-system-audio-tap` ADR, miniaudio loopback). |

**The cross-cutting insight:** the *only* approach that works uniformly across all three providers **and** keeps audio on-device is **no-bot system-audio capture** — which EarWitness is already building. Provider-specific bots buy per-speaker audio at the cost of complexity, fragility, per-platform native work, and exposure to the accelerating anti-bot crackdown.

---

## Vendor / DIY landscape (only relevant if a bot is required)

| Option | Platforms | Real-time audio | Self-host? | Audio through their cloud? | Cost |
|---|---|---|---|---|---|
| **On-device capture** (Meetily / Recall Desktop-SDK pattern) | any attended | n/a (local) | n/a | **No** | just compute |
| **Vexa** (Apache-2.0) | Meet, Teams (Zoom WIP) | ✅ diarized | ✅ "Vexa Lite" 1-container | No (self-host) | infra only |
| **Attendee** (open source) | Zoom (Meet/Teams WIP mid-2026) | ✅ | ✅ | No (self-host) | infra only |
| **Recall.ai** (hosted) | Zoom/Teams/Meet | ✅ per-speaker WS | ❌ SaaS | **Yes** | ~$0.50/hr + $0.15/hr transcription |
| **DIY browser automation** | any web client | mixed | ✅ local | No | high maintenance |

The **anti-bot arms race is accelerating** (Teams lobby detection 2026, Zoom/Google friction) — it taxes *every* bot approach, hosted or DIY, and especially DIY browser automation.

---

## Recommendation for EarWitness

1. **Core = on-device system-audio capture, no bot.** It's the only universal, private, low-maintenance path, and it's already the roadmap (story 861 + the macOS tap / miniaudio loopback work). Accept mixed far-side audio → far-side speaker separation stays a local-diarization problem (matches the documented v1 diarization limitation).
2. **Optional per-provider enhancement: Zoom Meeting SDK bot** — the one join-bot that runs locally *and* yields per-speaker audio. Worth it only if Zoom is a priority and the integration cost (native SDK via an OS-process port, headless-macOS + Marketplace-review questions resolved) pays off.
3. **Escape hatch if "capture meetings I'm not in" becomes a hard requirement:** self-hosted **Vexa** (private, you operate infra) over hosted **Recall.ai** (turnkey but audio leaves the device — a real exception to `local-first-privacy`). Recall is a good *spike bridge*, a weak *shipped architecture* for this product.

**Net:** the `meeting-bot-relay` ADR's "pick a vendor" framing is arguably the wrong question. For a local-first product the answer is mostly **"no relay — capture locally"**, with a Zoom-SDK bot as an optional quality upgrade and a self-hosted relay reserved for a not-attending requirement that may never materialize.

---

## Open items to verify before committing

- **Zoom Meeting SDK headless on macOS** — Linux headless is well-supported; macOS/Windows historically expect the Zoom client runtime. (zoom.md)
- **Zoom Marketplace review** — does "user records their own meetings on their own machine" need full app review, or count as private/own-account use? Gates time-to-ship. (zoom.md)
- **Meet Media API GA + enrollment gate** — if it has GA'd and dropped the all-participant-enrollment requirement since Apr 2026, it becomes the best local Meet path and flips that recommendation. (google-meet.md)
- **Auth housekeeping:** Zoom JWT app type is dead (2023-09-01) → OAuth / Server-to-Server OAuth.
