# Meeting Bots for Google Meet — Research (as of 2026-07-12)

Research for EarWitness: a local-first Elixir desktop transcription app that needs to join a
Google Meet call, capture BOTH sides of the audio, and feed it to on-device transcription.
This document surveys the current (2024–2026) ways to get Meet audio and assesses whether any
can run on the end user's machine.

## 1. TL;DR

- There are **four** distinct paths to Meet audio: the **Meet Media API** (real-time media,
  still Developer Preview in mid-2026), the **Meet REST API** (post-meeting artifacts only),
  the **Meet Add-ons SDK** (in-meeting side-panel apps — grants **no** raw media), and
  **browser automation** (drive the web client — historically the only way to get a "bot" into
  a call).
- **Only two paths give you raw two-sided audio: the Media API and browser automation.** REST
  gives you Google's own post-hoc transcript/recording, not live audio; Add-ons SDK gives you a
  UI panel, not audio.
- The **Media API is the "right" answer technically** — headless WebRTC client, no extra visible
  participant, native Opus streams — **but it is gated hard**: all participants + the Cloud
  project + the OAuth principal must be enrolled in Google's Developer Preview Program, admins
  must turn it on (off by default), and it needs restricted OAuth scopes (multi-week security
  review). This makes it **unusable for arbitrary/consumer meetings today.**
- **Browser automation is the only approach that works on any Meet call right now**, and it
  **can run locally** on the user's machine (headless Chromium + a virtual audio device). The
  cost: a fragile DOM/UI dependency, a visible bot participant that joins with a Google account,
  and ToS friction.
- **For a local-first desktop app, the pragmatic answer is browser automation running locally**,
  with the Media API as a forward-looking option to adopt once it reaches GA and the enrollment
  gate drops. Track the Media API's GA status.
- Consent/visibility differs sharply: a browser-automation bot **shows up as a participant**;
  the Media API is invisible as a participant **but Meet explicitly notifies everyone when the
  Media API is in use** and lets any participant turn it off.

## 2. Approaches comparison

| Approach | Audio access | Real-time? | Runs locally? | Maturity (mid-2026) |
|---|---|---|---|---|
| **Meet Media API** | Raw audio (3× Opus 48kHz stereo streams) + video + participant metadata, via WebRTC | Yes (live) | Yes — it's a WebRTC peer client (C++/TS); can run on the user's machine | **Developer Preview** (not GA); heavy enrollment + admin gate |
| **Meet REST API** | No live audio. Post-hoc **transcripts** (Google ASR text) + **recordings** (via Drive) + participant metadata | No (after meeting ends) | API calls can run locally, but data only exists after the call and only if host enabled recording/transcription | **GA** |
| **Meet Add-ons SDK** | **No media access** — side-panel UI only | n/a | Add-on runs in the Meet web client, not your app | **GA (Sept 2024)** |
| **Browser automation** | Raw tab audio (all participants mixed) via virtual sink + ffmpeg; or scrape live captions from DOM | Yes (live) | **Yes** — headless Chromium + virtual audio on the user's machine | Mature but **fragile / unofficial**; ToS-gray |

## 3. Official APIs in detail

### 3.1 Meet Media API (real-time media)
- **What it is:** Lets an application "access real-time media from Google Meet conferences" —
  video streams, audio streams, and participant metadata — over **WebRTC** (SDP offer/answer,
  DTLS, ICE, data channels for session control + stats).
- **Audio specifics:** Exactly **3 receive-only audio streams** per connection, **Opus codec,
  48kHz, 2 channels**. When participants exceed the stream cap, Meet servers send the audio of
  the "most relevant" participants (based on who's speaking, screen-sharing, etc.). Video is
  1–3 receive-only streams (VP8/VP9/AV1). Audio stream creation can be disabled in config.
  → This is enough to capture **both/all sides** of a typical small meeting's audio in real time.
- **Status & dates:** **Developer Preview** as part of the Google Workspace Developer Preview
  Program. Docs were still marked Developer Preview as of April 2026. **No GA date confirmed** as
  of this research (2026-07-12) — treat as not-yet-GA. *(Unverified: whether GA has been
  announced since; re-check the release notes.)*
- **Reference clients:** Google publishes **C++ and TypeScript** sample clients
  (github.com/googleworkspace/meet-media-api-samples). You can also build a custom WebRTC client.
- **Visible participant?** No — it provides "first-class access to the underlying realtime media
  streams without extra participants required," so it does **not** add a bot to the roster.
  However, Meet **notifies participants when the Media API is in use**, and each participant can
  turn it off (see §5).
- **Hard gates (the catch):**
  - **Everyone must be enrolled:** "The Google Cloud project, OAuth principal, and **all
    participants** in the conference must be enrolled in the Developer Preview Program." If a
    non-enrolled participant is present, the app **fails to receive data**.
  - **Consent:** a qualified consenter must be present — for Workspace meetings a host/co-host/
    initiator in the organizing org; for consumer Gmail meetings the initiator must be in the
    meeting. Consent is revocable mid-call and the stream terminates immediately.
  - **Cannot connect** when underage accounts are present, or when the meeting has
    client-side encryption or watermarking enabled, or if the host disables the setting mid-call.
  - **Restricted OAuth scopes** → per Recall.ai, a **4–7 week third-party security assessment**
    for production use.

### 3.2 Meet REST API (post-hoc artifacts)
- **What it is:** Read meeting **artifacts after the conference ends** — `conferenceRecords`,
  `conferenceRecords.transcripts` (Google ASR text + entries), `participants` /
  `participantSessions`, plus recording references.
- **No live media, no live audio.** Explicitly recommended by Google as the alternative to the
  Media API *for post-meeting* use.
- **Recordings** are not served by this API directly — recordings live in **Google Drive**, so
  you pull them via the **Drive REST API**. Transcripts/recordings only exist if the host
  enabled recording/transcription.
- **Scopes:** `https://www.googleapis.com/auth/meetings.space.created` or
  `.../meetings.space.readonly` (for transcripts, participants, etc.).
- **Status:** GA.
- **Relevance to EarWitness:** low — this yields Google's own transcript/recording after the
  fact, not raw two-sided audio for on-device transcription during the call. Could be a fallback
  "import my Google transcript" feature, not the core capture path.

### 3.3 Meet Add-ons SDK (in-meeting side panel)
- **What it is:** Build apps that run **inside the Meet web client** — a side panel (via
  `MeetSidePanelClient`) and main-stage surfaces, launched from the Activities button. Good for
  sharing data, notes, surveys, co-watching, collaborative state.
- **Status:** **Generally available since September 2024** (Developer Preview Dec 2023).
- **Media access?** **No.** The Add-ons SDK does not grant access to raw call audio/video. Any
  real-time media still comes from the separate Meet Media API. The add-on runs in Google's web
  client sandbox, not in your Elixir process.
- **Relevance to EarWitness:** not a capture path. Could theoretically host a companion UI, but
  a desktop app doesn't need it.

## 4. Auth / Workspace admin requirements

- **Google Cloud project + OAuth:** All official APIs require a Cloud project with OAuth
  credentials. Media API additionally requires the project **and** OAuth principal enrolled in
  the Developer Preview Program.
- **Workspace admin enablement for the Media API (off by default):**
  Admin console → **Apps > Google Workspace > Google Meet > Meet safety settings > Media API**.
  Admin must check "Let third-party apps that join a Meet call use the audio and video of the
  call through Meet Media API," then choose a consent model:
  - "Everyone from the host's org can give consent" (default), or
  - "Only the host or co-host can give consent."
  Available in Business, Enterprise, Essentials, Frontline, and G Suite Basic editions. Changes
  propagate within ~24h.
- **Same-Workspace requirement:** For **Workspace** meetings, the consenter must be in the org
  that owns the meeting. For **consumer (@gmail.com)** meetings, the initiator must be present to
  consent. The Media API does not strictly require the *app* to be in the same Workspace, but the
  **admin toggle + all-participants-enrolled** requirements effectively confine it to controlled
  environments today.
- **Browser automation auth:** requires a **real Google account** to log in and join. No Cloud
  project or scopes, but subject to login friction (CAPTCHA, session/2FA brittleness) and ToS.
- **REST API:** standard OAuth with the `meetings.space.*` scopes; no Developer Preview gate.

## 5. Participant visibility & consent

- **Browser-automation bot:** joins with a Google account and **appears in the participant
  roster** with a display name (and is subject to host admit/lobby). Fully visible.
- **Meet Media API:** does **not** add a visible participant, **but** "participants are informed
  when Meet API is in use in a meeting, and each participant can turn it off." So it is
  *disclosed* even though it's not a roster entry. Consent is required from a host/co-host (or
  the initiator for consumer meetings) and is revocable mid-call.
- **Google-native alternatives:** Meet's own **"meeting records" / Gemini "take notes for me"**
  and built-in recording/transcription produce artifacts you can later read via the REST/Drive
  APIs. These are first-party, clearly disclosed to participants, and avoid a third-party bot —
  but they are post-hoc and depend on the host enabling them and on the org's Gemini licensing.
- **Consent/compliance implication for EarWitness:** any capture approach should surface a clear
  in-app disclosure and, ideally, a participant-facing signal, given jurisdictions requiring
  all-party consent for recording.

## 6. Feasibility for a local-first desktop app (explicit)

**Question: can a Meet bot run ON the end user's machine from an Elixir desktop app?**

- **Browser automation — YES, locally.** The whole stack is local-capable: a headless (or
  headful) **Chromium** driven by Puppeteer/Playwright joins the call; the tab's audio is routed
  to a **virtual audio sink** (PulseAudio / `snd-aloop` on Linux; on macOS an equivalent virtual
  device like BlackHole/loopback) and **ffmpeg** (or a native capture) taps that sink to get
  mixed two-sided audio, which you feed straight into on-device transcription. Elixir can
  orchestrate this via a Port/NIF driving a Node/Playwright process or a `chromedriver`, plus an
  audio capture subprocess. **Caveats:** (a) it appears as a visible participant and needs a
  Google account to join; (b) it's **fragile** — Meet's DOM/UI changes break selectors, and
  login can hit CAPTCHA/2FA; (c) most published bot frameworks assume a **Linux server/container**
  (Docker, virtual X display, PulseAudio) because that's how they scale headlessly — replicating
  that reliably on a heterogeneous end-user Mac/Windows desktop is real engineering (virtual
  audio driver install, permissions). It's feasible but has an ongoing maintenance tax.
- **Meet Media API — technically YES locally, practically NO today.** The Media API client is
  just a WebRTC peer (C++/TS reference); nothing forces it into the cloud, so it *could* run in
  the desktop app (e.g., an embedded WebRTC client bridged to Elixir). **But** the
  Developer-Preview gate (all participants + project + principal enrolled), the admin-must-enable
  toggle, and restricted-scope security review make it **non-viable for general/consumer
  meetings right now.** It becomes the preferred local path **once it hits GA and the enrollment
  requirement is lifted**.
- **REST / Add-ons SDK — not local capture paths.** REST is post-hoc; Add-ons run in Google's
  web client. Neither gives the desktop app live raw audio.

**Bottom line:** For a local-first desktop app that must work on real Meet calls today, **local
browser automation is the only live-audio option that actually runs on the user's machine.** The
Media API is the strategically better local option but is blocked by preview gating until GA.

## 7. Recency notes (what changed 2024–2026)

- **Sept 2024:** Meet **Add-ons SDK went GA** (side-panel/main-stage apps).
- **2024→2026:** **Meet Media API** progressed through Developer Preview for real-time raw
  audio/video; Google shipped C++/TS sample clients (github.com/googleworkspace/meet-media-api-samples).
  Still **Developer Preview** in docs as of April 2026 — **no confirmed GA** at time of writing.
- **New admin surface:** a dedicated **Media API** control under Meet safety settings (off by
  default, per-org consent model) plus in-meeting participant notification + opt-out — a
  deliberate privacy posture around third-party media access.
- **Browser automation** remains the workhorse for universal Meet bots (Recall.ai, ScreenApp's
  open-source universal bot, numerous Puppeteer/Playwright projects, e.g. an Aug-2025 Python
  bot doing join+record+Whisper+summarize). Google **still provides no public API to make a bot
  join and pull live audio** outside the gated Media API, so DOM-scraping and virtual-audio
  capture persist — with the standing warning that Meet UI changes routinely break these bots.

## 8. Recommendation for EarWitness

1. **Ship on local browser automation first.** It's the only approach that captures live
   two-sided audio on **any** Meet call and **runs on the user's machine** — directly serving the
   local-first goal. Architect it as a replaceable "capture adapter" (join → virtual audio →
   PCM stream → on-device transcription) so the join mechanism is swappable.
2. **Isolate the fragility.** Centralize DOM selectors and join flow; add a lightweight
   self-test/health check; expect to patch when Google changes the Meet UI. Handle the visible-bot
   reality in the product (name the participant clearly, disclose recording).
3. **Solve virtual audio per-OS.** macOS: a loopback/virtual device (e.g., BlackHole-class) or
   Core Audio tap; Windows: WASAPI loopback; Linux: PulseAudio/`snd-aloop`. This, not the browser,
   is the hard cross-platform desktop piece.
4. **Keep the REST/Drive API as a secondary "import" feature** (pull Google's own transcript/
   recording after the call) for meetings where the host used Meet's native recording — cheap to
   add, no bot needed.
5. **Track the Meet Media API toward GA.** When it GAs and drops the all-participants-enrollment
   requirement, migrate the capture adapter to a local WebRTC Media API client: no visible bot,
   native Opus audio, far less fragile. Until then it's blocked for consumer/mixed meetings.
6. **Design consent in from day one** given the disclosure/opt-out norms Google is enforcing and
   all-party-consent recording laws.

## 9. Sources

- [Meet Media API overview — Google for Developers](https://developers.google.com/workspace/meet/media-api/guides/overview) — Developer Preview; enrollment/consent/cannot-connect rules; real-time positioning. Docs marked DP as of Apr 2026.
- [Meet Media API concepts — Google for Developers](https://developers.google.com/workspace/meet/media-api/guides/concepts) — 3 receive-only Opus 48kHz stereo audio streams; WebRTC; C++/TS clients; relevance-based stream selection.
- [Get started with Meet Media API — Google for Developers](https://developers.google.com/workspace/meet/media-api/guides/get-started) — setup/enrollment.
- [Meet Media API samples (GitHub, googleworkspace)](https://github.com/googleworkspace/meet-media-api-samples) — official C++/TypeScript reference clients.
- [Control Media API access in Google Meet — Workspace Admin Help](https://knowledge.workspace.google.com/admin/meet/control-media-api-access-in-google-meet) — off by default; admin toggle + consent model; participant notification/opt-out; supported editions.
- [What is the Google Meet Media API? — Recall.ai](https://www.recall.ai/blog/what-is-the-google-meet-media-api) — headless/no extra participant; all-participants-enrolled requirement; restricted-scope 4–7 wk review; revocable consent. Published Jul 16 2025, updated Jun 16 2026.
- [Meet REST API overview — Google for Developers](https://developers.google.com/workspace/meet/api/guides/overview) — post-hoc artifacts; conferenceRecords/transcripts/participants; recordings via Drive. GA.
- [conferenceRecords.transcripts — Meet REST API reference](https://developers.google.com/workspace/meet/api/reference/rest/v2/conferenceRecords.transcripts) — transcript resource model; `meetings.space.created`/`.readonly` scopes.
- [Meet Add-ons SDK is now generally available — Google Workspace Updates](https://workspaceupdates.googleblog.com/2024/09/google-meet-add-ons-sdk-is-now-available.html) — Add-ons SDK GA, Sept 2024.
- [Meet Add-ons SDK for Web overview — Google for Developers](https://developers.google.com/workspace/meet/add-ons/guides/overview) — side-panel apps; no raw media access; media comes from Media API.
- [How I built an in-house Google Meet bot — Recall.ai](https://www.recall.ai/blog/how-i-built-an-in-house-google-meet-bot) — Playwright/Chromium, DOM caption scraping vs audio, Docker/K8s cloud deployment, DOM fragility, visible bot. Updated Jun 28 2026.
- [Open Source Puppeteer Google Meet Bot — Recall.ai](https://www.recall.ai/blog/puppeteer-google-meet-bot) — Puppeteer join flow; virtual audio sink (PulseAudio/snd-aloop) + ffmpeg capture pattern.
- [screenappai/meeting-bot (GitHub)](https://github.com/screenappai/meeting-bot) — open-source universal Meet/Zoom/Teams recording bot; browser automation with anti-detection; production use.
- [dhruvldrp9/Google-Meet-Bot (GitHub)](https://github.com/dhruvldrp9/Google-Meet-Bot) — Aug 12 2025 Python bot: join + record audio + Whisper transcribe + GPT summarize; illustrates local browser-automation capture.
- [How to Integrate with Google Meet 2025 — ScreenApp](https://www.screenapp.io/blog/how-to-integrate-with-google-meet-2025) — states Google offers no public API for a bot to join/capture live audio; browser automation remains the norm.

## Uncertainty / to verify
- **Meet Media API GA status/date** — still Developer Preview per docs as of Apr 2026; confirm
  against the Meet release notes whether GA has since landed and whether the all-participants
  Developer-Preview enrollment requirement has been relaxed. This single fact flips the
  recommendation toward the Media API.
- **macOS/Windows virtual-audio specifics** for local desktop capture were inferred from
  general practice; the published bot frameworks are Linux/PulseAudio-centric. Validate the
  per-OS virtual-audio path during a spike.
