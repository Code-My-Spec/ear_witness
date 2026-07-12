# Meeting Bots — Zoom

Research date: **2026-07-12**. Prepared for the EarWitness architecture decision (local-first Elixir
desktop transcription; needs to capture BOTH sides of a Zoom call and feed on-device transcription).

Confidence note: Zoom's own docs are authoritative for API/SDK names and dates. Much of the "how it
actually behaves" detail comes from Recall.ai engineering blog posts (a hosted meeting-bot vendor).
Recall is a reliable secondary source but has a commercial interest in the "bots are hard, buy ours"
framing — treat their difficulty claims as directional, not gospel. Items I could not fully verify from
primary Zoom docs are marked **[unverified]**.

---

## 1. TL;DR

- **Two fundamentally different ways to get Zoom meeting audio in real time:** (a) a **bot participant**
  via the **Zoom Meeting SDK** (raw PCM audio, mixed + per-speaker, joins as a visible participant), or
  (b) **RTMS — Realtime Media Streams**, a **bot-less** WebSocket pipe that streams audio/video/transcript
  from Zoom's cloud. RTMS went **GA on 2025-06-25**.
- **For a local-first desktop app, the Meeting SDK bot is the only approach that can run entirely on the
  end user's machine.** The Meeting SDK is a native library (Windows/macOS/Linux) — an Elixir desktop app
  can drive it locally via a native port/NIF and receive raw PCM in-process. No cloud required.
- **RTMS structurally requires cloud infrastructure** you host: Zoom pushes media to a **publicly
  reachable WebSocket endpoint** triggered by an account webhook. It is not a fit for a purely local app
  unless you stand up a relay server. It is also **receive-only** and **Zoom-only**.
- **Raw audio no longer needs a special Zoom entitlement** (the old admin "raw data" toggle is gone).
  Access is now gated by **meeting role / recording permission**: the bot must be host, co-host, or be
  granted local-recording permission (interactively or via a **local recording join token**).
- **JWT apps are dead** (disabled 2023-09-01). Use **OAuth / Server-to-Server OAuth**; RTMS apps are
  registered as a **"General App"** with RTMS scopes.
- **A bot participant is visible and subject to consent/notification**; RTMS still requires host approval
  of realtime sharing (Zoom client 6.5.5+) and account enablement. There is no invisible-capture path
  that is also ToS-clean.

---

## 2. Approaches comparison

| Approach | Audio access | Real-time? | Runs locally on user machine? | Maturity (2026-07) |
|---|---|---|---|---|
| **Meeting SDK** (bot joins as participant, raw data) | Raw PCM 16LE; **mixed AND per-speaker**; both directions of the call | Yes, in-meeting callbacks | **Yes** — native lib (Win/macOS/Linux), driveable in-process from a desktop app | Mature, widely used |
| **RTMS / Realtime Media Streams** (bot-less) | Raw audio (G.722/PCM, speaker-separated channels) + video + live transcript | Yes, WebSocket | **No** (structurally) — Zoom pushes to your hosted public WS endpoint via webhook | GA **2025-06-25**; self-serve purchasing live 2025 |
| **Video SDK** | Full audio/video, but for apps building their OWN sessions | Yes | Yes, but N/A — it does **not** join normal Zoom *Meetings* | Mature, wrong tool |
| **Zoom Apps** (in-client web app) | No raw participant audio pipe | — | Runs in Zoom client | Not an audio-capture path |
| **Browser automation** (headless Chromium joins web client) | Audio via screen/tab capture (WebM), mixed only, brittle | Yes | Yes (local headless browser) | Hacky, fragile, ToS-gray |
| **REST API cloud recording + webhooks** | Full recording files | **No — post-meeting** | Download locally, but capture is cloud | Mature, but not live |

---

## 3. Official SDKs / APIs in detail

### Zoom Meeting SDK — bot join + raw data  (primary candidate)
- **What it is:** native SDK that programmatically joins a *standard Zoom Meeting* as a participant.
  Available for **Windows, macOS, Linux** (Linux is the headless/server variant commonly used for bots),
  plus iOS/Android and Web.
- **Raw audio:** SDK "Raw Data" callbacks deliver **PCM 16LE**. Two forms:
  - **Mixed** audio of all participants: `onMixedAudioRawDataReceived`.
  - **Per-participant / per-speaker** streams (individual channels) — enables diarization-by-source.
  - Video (if wanted) as I420/YUV420 raw frames.
  - Delivery is **real-time**, in-process, during the meeting. Enabling raw data does **not** trigger
    Zoom's cloud or local recording; it just turns on the callbacks.
- **No special entitlement anymore:** "You no longer need a special entitlement from Zoom to use raw data
  in the Meeting SDK." The old admin toggle was deprecated; access is now purely role/permission based
  (source: Recall.ai, 2025). **[partially verified — corroborate against current Zoom docs before relying]**
- **Permission model (the real gate):** on Windows/macOS the app must be **host, co-host, or granted
  local-recording permission** by the host. `rc=12 (NO_PERMISSION)` = not granted. Two ways to get it:
  1. Join, then call `IMeetingRecordingController::RequestLocalRecordingPrivilege()` → host sees a prompt.
  2. Pre-authorize with a **local recording join token** (see §4) so the bot auto-records with no prompt.
- **Marketplace review:** a Meeting SDK app that joins meetings **outside your own account** must be
  submitted for Marketplace review before distribution. A bot that only joins your *own* account's
  meetings does not need review. For EarWitness (each user drives their own Zoom sessions on their own
  machine) this is a real question to resolve — see §6/§8.

### RTMS — Realtime Media Streams  (bot-less real-time pipe)
- **Status/date:** Developer preview early 2025 → **GA announced 2025-06-25** ("available to all
  developers"). Self-service purchasing added later in 2025. Works with **Zoom Meetings, Video SDK, and
  Contact Center**.
- **What it delivers:** live **audio, video, transcript, chat, screen-share** from a meeting — **without
  a bot participant in the meeting**. This is its headline advantage.
- **Transport:** two-phase WebSocket.
  1. **Signaling WebSocket** — authenticate, negotiate which streams you want.
  2. **Media WebSocket** — receives the media packets.
  - Audio default **mono G.722 @ 16 kHz**, configurable to stereo and 8/32/48 kHz; **speaker-separated
    channels** supported; ~20 ms packet interval (configurable). Video JPG/PNG ≤5 fps or H.264 up to
    30 fps. Transcript arrives as UTF-8 with speaker attribution + timestamps.
- **Trigger:** subscribe to the **`meeting.rtms_started`** webhook; when it fires you open the signaling
  handshake. This is why RTMS needs a **publicly reachable server** — Zoom's cloud initiates/expects an
  externally reachable endpoint.
- **Auth:** **HMAC-SHA256** signature: `HMAC(client_id + "," + meeting_uuid + "," + rtms_stream_id, client_secret)`.
  App registered as a **General App** with RTMS scopes.
- **Limits:** **receive-only** (cannot send audio/video/chat back — "bidirectional not supported").
  Zoom-only. Breakout-room support undocumented/unsupported **[unverified]**. Requires **account credits**
  (paid; volume >500 credits = contact sales).
- **Official wrapper:** `github.com/zoom/rtms` — C++ SDK with **Node.js, Python, Go** bindings. (No Elixir
  binding; you'd wrap the C++ SDK or talk the WebSocket protocol directly.)

### Video SDK — *not the right tool*
- Builds your own custom audio/video sessions on Zoom infra; does **not** join ordinary Zoom Meetings.
  Only relevant if EarWitness ran its own conferencing, which it does not. Note RTMS can also feed off
  Video SDK sessions.

### Zoom Apps — *not an audio pipe*
- In-client embedded web apps (panels/side-by-side). Good for UI inside Zoom, **no raw participant audio
  stream**. Not a capture mechanism.

### REST API + Cloud Recording — *post-meeting only*
- `GET /v2/meetings/...` recording endpoints + `recording.completed` webhook give full files **after** the
  meeting. Useful as a fallback/batch path, useless for live transcription.

---

## 4. Auth / permissions / admin consent

- **JWT apps: deprecated.** No new JWT apps after **2023-06-01**; JWT auth **disabled 2023-09-01**. Do not
  design around JWT. (Some old Meeting SDK auth flows historically used a JWT-style SDK signature — that is
  the *SDK signature*, separate from the deprecated *JWT app type*; still generate the Meeting SDK JWT
  signature from your SDK key/secret.)
- **Use OAuth 2.0:** user-level OAuth (host authorizes your app) or **Server-to-Server OAuth**
  (account-level, no user click, for backend automation).
- **Local recording join token (Meeting SDK auto-record):**
  - Endpoint: `GET /v2/meetings/{meetingId}/jointoken/local_recording`.
  - Scopes: `meeting:read:local_recording_token` (and `:admin` variant).
  - Flow: host authorizes your OAuth app → get host access token → fetch token → pass to SDK `join()`.
  - **Token expires in ~120 s**, single meeting occurrence. Lets the bot **skip waiting room + auto-record
    without a per-meeting prompt**.
  - Account prerequisites: local recording enabled; participants permitted to record locally; in-meeting
    setting allows participant local recording.
- **RTMS:** admin enables RTMS account-wide (on by default); host approves realtime sharing (client
  **6.5.5+**); app is a General App with RTMS scopes; HMAC signature per stream.
- **Marketplace review latency:** publishing a distributable Meeting SDK / OAuth app typically takes
  **weeks** and may need org-admin approval depending on the customer's security policy.

---

## 5. Participant visibility & consent

- **Meeting SDK bot = a visible participant.** It shows in the roster (typically named, e.g. "EarWitness
  Notetaker"). Normal join flow: waiting room → host admits → bot requests recording permission (unless a
  join token pre-authorizes). This is the transparent, consent-friendly model.
- **Recording notification:** when recording is active, Zoom surfaces the standard recording indicator/
  consent to participants. Recall's compliance guidance and Zoom's own policies stress you must make it
  clear an assistant/notetaker is present and comply with local two-party-consent laws.
- **RTMS is bot-less** (no roster entry), but it is **not** silent capture: the host must approve realtime
  media sharing and the account must have RTMS enabled. Consent obligations still apply.
- **There is no ToS-clean invisible-capture path.** Browser-automation "ghost" participants still appear
  in the roster and still trip recording consent; hiding presence would be a policy violation.

---

## 6. Feasibility for a local-first desktop app  (the key axis)

**Meeting SDK bot — CAN run fully locally. This is the fit.**
- The Meeting SDK is a **native library** (macOS `.framework`/dylib, Windows DLL, Linux `.so`). A desktop
  app on the user's machine loads it, joins the meeting, and receives **raw PCM in-process** — no server,
  no cloud, no per-stream bandwidth cost. Audio never leaves the device, which matches EarWitness's
  local-first / on-device-transcription posture perfectly.
- **Elixir integration:** no official Elixir binding. Realistic options:
  1. **C/C++ NIF or (safer) a C-node / external OS-process "port"** wrapping the native SDK, streaming PCM
     frames into the BEAM over a port. A separate OS process is safer than a NIF (SDK crash/blocking won't
     take down the VM).
  2. On **Linux** the SDK has a **headless** variant designed exactly for bots (no GUI). On macOS/Windows
     the SDK historically expects to spin up Zoom client UI/runtime — **verify the current macOS headless
     story**, since EarWitness's primary desktop targets matter here **[unverified for macOS headless]**.
- **Capturing BOTH sides:** raw-data mixed audio already contains all participants (local user + remote);
  per-speaker callbacks additionally give source-separated channels — directly useful for EarWitness's
  diarization goals (ties to the diarization-v1 limitation note: per-source channels make within-recording
  separation far easier than post-hoc clustering).
- **The catch is permissions + distribution, not architecture:** each meeting the bot records needs host/
  co-host/local-recording permission or a join token, and a broadly distributed app that joins arbitrary
  customers' meetings needs Marketplace review. For EarWitness's likely model (the user is recording their
  *own* meetings on their *own* machine), the user is often the host or can self-grant — lowest friction.

**RTMS — does NOT fit a purely local app.**
- Zoom pushes media to a **public WebSocket endpoint** driven by an **account-level webhook**. That
  requires a hosted, internet-reachable service you operate + paid credits. You could build a thin cloud
  relay that forwards to the desktop, but that abandons local-first (audio transits your server) and adds
  cost. Also receive-only and Zoom-only. **Not recommended for EarWitness's core path.**

**Browser automation — technically local, but weak.**
- A local headless Chromium (Puppeteer/Playwright) can join the Zoom **web client**; audio via tab/screen
  capture (WebM) is **mixed-only** (no clean per-speaker), needs fake-media-device flags to satisfy
  mic/cam permission checks, and **breaks whenever Zoom changes its web UI**. Fine for a spike, poor for a
  shipping product.

---

## 7. Recency notes (what changed 2024–2026)

- **2023-09-01:** JWT app type disabled — OAuth/S2S OAuth only. (Pre-window but still the governing state.)
- **2025 (early):** RTMS **developer preview** announced.
- **2025-06-25:** **RTMS GA** — "available to all developers." Biggest recent shift: a first-party,
  **bot-less** real-time media pipe. Later in 2025, **self-service purchasing** for RTMS credits.
- **2025:** Confirmation that Meeting SDK **raw data no longer needs a special entitlement** — lowers the
  barrier to building a raw-audio bot **[corroborate on current Zoom docs]**.
- **2025 (Oct):** Recall published detailed guides on **local recording join tokens** and **compliance**,
  reflecting the current permission/consent model.
- `zoom/rtms` official multi-language wrapper (Node/Python/Go) published — signals Zoom investing in RTMS
  as the strategic real-time path.

---

## 8. Recommendation for EarWitness

1. **Primary: Zoom Meeting SDK bot, driven locally from the desktop app.** It is the *only* approach that
   keeps audio on-device (local-first), gives **both sides** as raw PCM, and offers **per-speaker
   channels** that directly help diarization. Integrate via an **external OS-process port** wrapping the
   native SDK (not a NIF) to isolate crashes from the BEAM.
2. **Resolve two open items before committing (both are "unverified" above):**
   - **macOS headless behavior** of the Meeting SDK — does it truly run without visible Zoom UI on the
     user's Mac, and what's the packaging/entitlement story for a distributed desktop app?
   - **Marketplace review scope** — does EarWitness's usage (user records their own meetings) require full
     Marketplace publication, or does it fall under own-account/private use? This gates time-to-ship.
3. **Permissions UX:** design around the host-permission reality — prefer the **local recording join
   token** flow (OAuth, ~120 s token) so recording starts without a manual prompt where the user has
   rights; fall back to `RequestLocalRecordingPrivilege()` prompt otherwise. Always show the bot as a
   clearly-named participant and surface recording consent (aligns with EarWitness consent goals).
4. **Do NOT build the core on RTMS.** It contradicts local-first (requires your hosted public endpoint +
   paid credits, audio transits cloud) and is receive-only/Zoom-only. Keep it as a *possible future*
   optional cloud path for users who can't/won't run a local bot, not the foundation.
5. **Keep browser automation only as a throwaway spike** if you need a quick proof before the native SDK
   port is ready. Don't ship on it.

Net: **Meeting SDK bot = viable locally and is the recommendation. RTMS = powerful but structurally
cloud, so not for the local-first core.**

---

## 9. Sources

- [Zoom RTMS docs](https://developers.zoom.us/docs/rtms/) — official; what RTMS is, credits/purchasing.
- [RTMS "now available to all developers" changelog](https://developers.zoom.us/changelog/rtms/june-25-2025/) — **GA date 2025-06-25**.
- [RTMS developer-preview blog](https://developers.zoom.us/blog/realtime-media-streams/) — preview announcement, pre-GA.
- [RTMS getting started](https://developers.zoom.us/docs/rtms/meetings/getting-started/) — webhook + handshake flow.
- [zoom/rtms GitHub](https://github.com/zoom/rtms) — official C++ SDK wrapper w/ Node/Python/Go bindings (no Elixir).
- [Recall.ai — What is Zoom RTMS](https://www.recall.ai/blog/what-is-zoom-rtms) — WebSocket 2-phase, codecs, HMAC auth, host approval 6.5.5+, receive-only limits. (2025-07-04, upd 2026-06-19)
- [Zoom Meeting SDK docs](https://developers.zoom.us/docs/meeting-sdk/) — official; platforms, join, raw data.
- [Recall.ai — Access raw data in the Meeting SDK](https://www.recall.ai/blog/how-to-access-raw-data-in-the-zoom-meeting-sdk) — mixed vs per-speaker PCM, no special entitlement, rc=12 permission.
- [Recall.ai — Capturing video/audio via Zoom SDK](https://www.recall.ai/blog/zoom-sdk-receiving-video-streams) — PCM 16LE / I420 frame formats.
- [Recall.ai — Zoom SDK recording permissions](https://www.recall.ai/blog/zoom-sdk-recording-permissions) — host/co-host/local-recording gate, request-privilege flow.
- [Recall.ai — Zoom SDK compliance requirements](https://www.recall.ai/blog/zoom-sdk-compliance-requirements) — Marketplace review scope, consent. (2025-10-13)
- [Recall.ai — Zoom join tokens for local recording](https://www.recall.ai/blog/zoom-join-tokens-for-local-recording) — jointoken/local_recording endpoint, scopes, 120 s token. (2025-10-23)
- [Recall.ai — Create audio/video capture bots](https://www.recall.ai/blog/create-audio-video-capture-bots) — overall bot capture overview.
- [DEV — Building a Zoom Meeting Bot in 2025 on AWS](https://dev.to/atsimabistov/building-a-zoom-meeting-bot-in-2025-on-aws-2k4h) — Linux-headless bot reference arch; note its cloud-first framing.
- [Zoom — Video SDK vs Meeting SDK comparison](https://support.zoom.com/hc/en/article?id=zm_kb&sysparm_article=KB0064689) — official product boundary.
- [Zoom — JWT app type deprecation changelog](https://developers.zoom.us/changelog/platform/jwt-app-type-deprecation/) — JWT disabled 2023-09-01, use OAuth/S2S.
- [Recall.ai — How to join Zoom using Puppeteer](https://www.recall.ai/blog/how-to-join-zoom-using-puppeteer) — browser-automation join, fake media flags, UI fragility.
