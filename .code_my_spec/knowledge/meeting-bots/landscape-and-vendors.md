# Meeting-Bot Infrastructure: Landscape & Vendors (2024–2026)

_Research compiled 2026-07-12 for the EarWitness `meeting-bot-relay` ADR._
_Decision at stake: (a) hosted meeting-bot relay vendor vs. (b) DIY browser-automation joiner, possibly run locally, for an Elixir local-first / privacy-focused desktop transcription app._

> **Verification note:** Prices and platform-support claims come from vendor pricing/docs pages and recent (2025–2026) comparison articles, cross-checked where possible. Vendor-authored comparisons (Recall.ai, Skribby, MeetingBaaS, MeetStream all publish "vs competitor" pages) are inherently biased — treated as directional, not authoritative. Items I could not independently verify are marked _(unverified)_.

---

## 1. TL;DR

- **Two axes matter, not one.** There's the *joiner* mechanism (bot-in-the-meeting vs. on-device capture) and the *hosting* model (SaaS cloud vs. self-host/on-device). For a privacy/local-first app, the hosting axis dominates: **any hosted bot vendor routes your users' meeting audio through their cloud**, which is architecturally at odds with EarWitness's positioning.
- **Recall.ai is the incumbent** and the "just works" option: Zoom/Teams/Meet/Webex/GoTo/Slack, ~$0.50/recording-hour + $0.15/hr transcription (dropped from $0.70 in early 2026), no platform fee — but SaaS-only, audio flows through their cloud.
- **Two open-source, self-hostable relays exist**: **Attendee** (Django/Postgres/Redis, MIT-ish, Zoom working today, Meet/Teams on roadmap as of mid-2026) and **Vexa** (Apache-2.0, Meet solid + Teams/Zoom, real-time Whisper transcription, "Vexa Lite" single-container GPU-free deploy). Both let you keep audio on infrastructure you control.
- **The genuinely local-first pattern is *not a bot at all*.** Tools like **Meetily** (and Recall.ai's own **Desktop Recording SDK**) capture system/mic audio on the user's machine — no participant bot joins the call. This sidesteps the cloud-routing problem AND the escalating anti-bot arms race entirely. For a desktop app this is the natural fit.
- **The anti-bot arms race is real and accelerating.** Microsoft Teams (2026), Zoom, and Google are all rolling out bot-detection / lobby-approval / admin-block controls. DIY browser-automation bots are a perpetual maintenance treadmill (UI selectors break, detection tightens); this is exactly the pain hosted vendors sell you out of.
- **Sharpest tradeoff for the ADR:** privacy/local-first vs. "join meetings the user isn't physically in." Bots (hosted or DIY) can join remote/unattended meetings but route audio through a joiner; on-device capture keeps audio local but only works for meetings the user is actually attending on that machine.

---

## 2. Vendor / Option Comparison Table

| Option | Platforms | Real-time audio? | Self-hostable? | Pricing (recording) | Audio through their cloud? | Notes |
|---|---|---|---|---|---|---|
| **Recall.ai** (Bot API) | Zoom, Teams, Meet, Webex, GoTo, Slack | Yes (output streaming) | **No** (SaaS) | ~$0.50/hr + $0.15/hr transcription; no platform fee | **Yes** | Incumbent, best docs/coverage, SOC2/ISO/HIPAA |
| **Recall.ai Desktop SDK** | Any (captures system+mic audio locally) | Yes | Capture is local; upload/processing via Recall cloud | Same ~$0.50/hr | **Partly** (local capture, cloud upload by default) | No bot joins the call; on-device capture |
| **MeetingBaaS** | Zoom, Teams, Meet | Yes (WebSocket + Pipecat speaking bots) | **Yes** — on-prem offer (~$5.5k/mo base, then $0.066/hr) | Usage-based hosted; on-prem tier | Yes (hosted) / No (on-prem) | Open-source components; on-prem is enterprise-priced |
| **Vexa** | Meet (strong), Teams, Zoom | **Yes** — sub-second, speaker-diarized WebSocket | **Yes** (Docker/K8s; "Vexa Lite" single container) | Cloud from ~$0.30/hr bot + ~$0.20/hr transcription | Hosted: yes / Self-host: **No, stays on your infra** | Apache-2.0; Whisper local; newest (launched early 2025) |
| **Attendee** | Zoom (live); Meet + Teams on roadmap | Post-meeting primarily _(realtime maturing)_ | **Yes** (single Docker image + Postgres/Redis) | Free/self-host (Deepgram key for transcription) | **No** when self-hosted | ~660 GitHub stars, very active (v1.55.x Jul 2026); "10x cheaper self-hosted" claim |
| **Skribby** | Zoom, Teams, Meet | Yes (add-on / included on realtime models) | No (SaaS) | $0.35/hr bot; $0.39–0.70/hr with transcription | Yes | Cheapest hosted headline; 10+ transcription models |
| **MeetStream** | Zoom, Teams, Meet (Webex/Slack roadmap) | **Yes** — per-speaker PCM16 WebSocket | No (SaaS) | Usage-based _(unverified specifics)_ | Yes | Pitches strongest real-time + in-meeting AI agents |
| **Nylas Notetaker** | Zoom, Teams, Meet | No (post-meeting) | No (SaaS) | Bundled w/ Nylas _(unverified)_ | Yes | Best if already in Nylas calendar ecosystem |
| **Meetily** (OSS) | Any (system-audio capture, no bot) | Yes (local) | **Yes** — 100% local, offline | Free (MIT); Community Edition | **No** — never leaves device | Not a relay; on-device notetaker, ~20k stars |
| **DIY (Puppeteer/Selenium)** | Per-platform, you build each | Possible (virtual audio devices) | **Yes** (your infra or local) | Your compute only | Only if you route it | High + perpetual maintenance burden |

_Prices are per recording-hour and current as of the cited 2026 sources; verify on vendor pages before quoting._

---

## 3. Hosted Vendors in Detail

### Recall.ai — the incumbent
- **What:** "Meeting Bot API for every platform." A single API deploys a bot that joins Zoom, Google Meet, Microsoft Teams, Webex, GoTo Meeting, and Slack Huddles, records, and streams/returns audio + video + transcript.
- **Pricing (early 2026):** Dropped from $0.70 to **$0.50 per recording-hour** (same rate for Bot API and Desktop SDK). Built-in transcription **$0.15/hr** (or bring-your-own provider). **No monthly platform fee** anymore — pure usage-based, prorated to the second. 7 days free storage, then $0.05/hr per additional 30 days. Calendar API included free. (Pricing page dated Mar–May 2026.)
- **Privacy:** SOC 2, ISO 27001:2022, GDPR, CCPA, HIPAA compliant. **But the bot runs in Recall's cloud — meeting audio necessarily passes through their infrastructure.** No self-host option for the Bot API.
- **Recency/maturity:** Market leader, widest platform coverage, strongest docs and SDKs. Well-funded (see Sacra profile). Real-time audio is output-streaming oriented; per-speaker separation is comparatively limited (competitors attack this).
- **Also offers the Desktop Recording SDK** — see §5; this is the privacy-relevant product.

### MeetingBaaS (Meeting BaaS / "Meeting Bots as a Service")
- **What:** Developer API across Zoom/Meet/Teams. Custom bot name/avatar, raw audio+video, transcripts, real-time metadata. Notable **Speaking Bots API** (conversational bots that listen + speak via WebSocket audio + Pipecat).
- **Self-host:** Hosted by default, **but offers an on-prem deployment** — base setup estimated ~**$5,500/month**, then **$0.066/hr** for bots with an SLA. Many components are open-source (`Meeting-Baas/meet-teams-bot` on GitHub).
- **Privacy:** Hosted routes through their cloud; on-prem keeps it on your infra (at enterprise cost).
- **Recency:** Active 2025–2026; positions as the simpler-API, developer-friendly Recall alternative.

### Vexa — open-source, real-time, self-hostable (most interesting for privacy)
- **What:** Apache-2.0 open-source meeting bot API. Bot joins as a normal participant **from a headless browser**, no Google Workspace add-on or Gemini dependency. Real-time, speaker-diarized transcripts over WebSocket with sub-second latency. REST + WebSocket + MCP interfaces.
- **Platforms:** Google Meet is the mature path; Teams and Zoom listed as supported (Meet clearly strongest per their docs).
- **Transcription:** Whisper running **locally or in their cloud** — "audio never leaves infrastructure you control when self-hosted." 100+ languages, real-time translation.
- **Self-host:** Docker or Kubernetes. **Vexa Lite** = single-container deploy, no GPU required (uses external transcription), "80% less operational overhead."
- **Pricing:** Cloud bots from **~$0.30/hr** + transcription add-on ~$0.20/hr; self-host = your compute only.
- **Recency:** Launched early 2025, actively marketed through 2026. Newest of the pack — smaller track record, verify robustness.

### Attendee — open-source, self-host-first
- **What:** "The universal Meeting Bot API," open-source, built for self-hosting. Runs as a **single Django Docker image + Postgres + Redis**. Bots access "the same audio/video streams as human users." Notably integrates Zoom's official **RTMS (Real-Time Media Streams)** — a sanctioned data path rather than pure scraping.
- **Platforms (mid-2026):** **Zoom is live**; Google Meet and Microsoft Teams are on the roadmap (not yet complete per the repo). This is a real limitation today.
- **Transcription:** Post-meeting via Deepgram (bring your key; ~400 free hours on signup). Real-time is maturing.
- **License/maturity:** Open source; ~660 stars, ~4,400 commits, 115+ releases, latest **v1.55.1 dated 2026-07-10** — very active. Claims **~10x cost reduction** vs. closed vendors when self-hosted.
- **Privacy:** Self-hosted → **audio stays on your infrastructure.**

### Skribby
- **What:** Hosted bot API for Zoom/Teams/Meet. Headline **$0.35/hr** bot (cheapest hosted base), no monthly fee; $0.39–0.70/hr with transcription depending on model (Whisper/Deepgram/AssemblyAI, 10+ options). Real-time audio via WebSocket (add-on / included on realtime models); **no real-time video**.
- **Privacy:** SaaS, audio through their cloud. No self-host found.

### MeetStream
- **What:** Hosted; differentiates on **per-speaker PCM16 real-time audio over WebSocket** and in-meeting AI agents. Zoom/Teams/Meet, Webex/Slack on roadmap.
- **Privacy:** SaaS. Pricing specifics _(unverified)_.

### Nylas Notetaker
- **What:** Post-meeting recording/transcription bot, best when you're already using Nylas for calendar/email. No real-time, no self-host. Calendar-native scheduling is the draw.

---

## 4. DIY Browser-Automation Options

**Approach.** Drive a headless Chromium (Puppeteer or Selenium/Playwright) to open the meeting's **web client**, sign in with a Google/throwaway account, mute cam/mic, join, and capture media. Audio is captured by routing the browser's output through a **virtual audio device** (`snd-aloop` / PulseAudio on Linux, Loopback/BlackHole on macOS) and recording with `ffmpeg`/`pyaudio`, then transcribing via Whisper/Deepgram. Screen+audio can also be grabbed via `puppeteer-screen-recorder` or a "ghost participant" WebRTC recording pattern.

**Open-source references:**
- `screenappai/meeting-bot` — universal bot for Meet/Zoom/Teams, Docker, uses chrome-CDP sidecars; "runs in production," MIT-ish, most complete DIY starting point.
- `Ritika-Das/Google-Meet-Bot` — Puppeteer + Node, stealth Google sign-in, join/mute/caption; single-platform demo.
- Recall.ai's own engineering blogs ("How I built an in-house Google Meet bot," "Open Source Puppeteer Google Meet Bot") candidly document the approach — and why they sell you out of it.
- Zoom's **RTMS (Real-Time Media Streams)** and Meet/Teams official media APIs are the sanctioned alternatives to browser scraping where available (Attendee uses RTMS for Zoom).

**Burden / robustness.**
- **UI fragility:** Selectors break whenever Meet/Teams/Zoom ship UI changes ("work as of early 2025, may change" is the standard disclaimer). Each platform is a separate codebase + separate breakage schedule.
- **Anti-bot arms race (accelerating 2025–2026):** Microsoft Teams is rolling out (2026) admin-controlled external-bot detection that routes suspected bots to the lobby for organizer approval, replacing CAPTCHA join checks. Zoom has account-wide third-party-AI-bot blocking (inconsistent as of Feb 2025 but tightening). Google similarly. Expect joins to be blocked, lobbied, or flagged more over time. Security vendors (Palo Alto) now actively frame unauthorized meeting bots as a threat to stop.
- **Per-platform difficulty:** Meet (web-client scraping) is the most documented/tractable; Zoom offers RTMS/SDK paths that are more stable if you go official; Teams is the hardest and now the most aggressively policed.
- **Verdict:** DIY is viable for a spike or a single platform, but sustaining Zoom+Teams+Meet against ongoing UI + policy churn is a real, open-ended maintenance commitment — the core reason the hosted-vendor market exists.

---

## 5. Local-First / Privacy Analysis

**The unavoidable fact about hosted relays:** a meeting bot is a participant that *ingests the meeting's audio*. If that bot runs in a vendor's cloud (Recall, Skribby, MeetStream, Nylas, MeetingBaaS-hosted, Vexa-cloud), **every user's meeting audio transits and is processed on third-party servers.** Compliance certifications (SOC2/HIPAA/GDPR) govern *how* they handle it, but the audio still leaves the user's machine and the user's org's control. For a product whose entire pitch is local-first and privacy, that's a direct contradiction of the value prop — and a thing you'd have to disclose in a privacy policy and possibly a DPA.

**What keeps audio on-device / on-your-infra:**

| Pattern | Where audio lives | Fit for EarWitness |
|---|---|---|
| **On-device system-audio capture (no bot)** — Meetily-style, Recall Desktop SDK (local capture portion) | User's machine | **Best privacy fit.** Matches a desktop app. Only captures meetings the user attends on that device. |
| **Self-hosted relay** — Attendee, Vexa (self-host), MeetingBaaS on-prem | Your (or user's) own server/infra | Keeps audio off *third-party* cloud, but for a *desktop* app "self-host a server" pushes ops onto you or the user. Vexa Lite (single container, no GPU) is the most plausible if a bot is truly required. |
| **Hosted relay** — Recall, Skribby, MeetStream, etc. | Vendor cloud | Fastest to ship, worst privacy story. |

**Key nuance on Recall's Desktop SDK:** it captures mic+system audio **locally with no bot joining the call** — great — but by default it uploads to Recall's cloud for processing/storage (the "Create Desktop SDK Upload" flow). So it solves the *bot-in-the-meeting* problem, not automatically the *audio-in-vendor-cloud* problem, unless configured for real-time local handling. Meetily, by contrast, processes everything locally by design (offline, GDPR/HIPAA-by-architecture).

**The strategic point:** for a **desktop** app, the bot-vs-no-bot question is arguably more important than the vendor question. On-device capture (the Meetily / local-Desktop-SDK pattern) is both the most private *and* the most robust — it never touches the anti-bot arms race, because nothing joins the call.

---

## 6. Cost & Effort Comparison (small team shipping a desktop app)

| Approach | Upfront effort | Ongoing maintenance | Marginal cost | Privacy |
|---|---|---|---|---|
| **Hosted relay (Recall/Skribby/etc.)** | Low (days) | Low — vendor absorbs UI/policy churn | ~$0.35–0.65/hr all-in | Worst (vendor cloud) |
| **Self-host Attendee/Vexa** | Medium–High (stand up + operate services; Meet/Teams gaps in Attendee today) | Medium — you inherit some platform churn + run infra | Compute only (~10x cheaper claimed) | Good (your infra) |
| **MeetingBaaS on-prem** | Medium | Low–Medium (vendor SLA) | ~$5.5k/mo + $0.066/hr | Good (on-prem) but enterprise $$ |
| **On-device capture (Meetily-style / Desktop SDK)** | Medium | **Lowest** — no bot, no join churn | ~Free (local) or Desktop-SDK per-hr | **Best** (on-device) |
| **DIY browser bot** | High (per platform) | **Highest** — perpetual selector + anti-bot fixes | Compute only | Depends where you run/route |

For a small team, hosted relay minimizes *engineering* cost but maximizes *privacy* cost and *per-hour* cost at scale. On-device capture minimizes both privacy cost and long-run maintenance, at the price of only covering meetings the user personally attends.

---

## 7. Recommendation for EarWitness

Given EarWitness's **local-first, privacy-focused, Elixir desktop** identity, the realistic shortlist is:

1. **On-device system-audio capture (no bot) — recommended default.** This is the pattern Meetily proves and Recall's Desktop SDK productizes. It matches a desktop app's grain: capture the audio already playing on the user's machine, transcribe locally (you already have a transcription spike). No cloud routing, no anti-bot arms race, cleanest privacy story. **Limitation:** only captures meetings the user is actually in on that device — no unattended/remote joining, and speaker diarization is harder from a single mixed stream (consistent with your documented diarization-v1 limitation).

2. **Self-hosted Vexa (or Attendee) — if a bot that joins on the user's behalf is a hard requirement.** Vexa is the best privacy-preserving *relay*: Apache-2.0, self-hostable, Whisper local, real-time diarized transcripts, and "Vexa Lite" makes a single-container deploy plausible. Attendee is architecturally clean (single Django image) and very active, but **Meet/Teams support isn't done as of mid-2026** — a blocker if you need all three now. Either way, "run a server" sits awkwardly with a pure desktop app; you'd be shipping/operating backend infra.

3. **Recall.ai (hosted) — only as a pragmatic bridge / spike.** Fastest path to Zoom+Teams+Meet coverage and the most robust against platform churn, but it routes user audio through their cloud, which contradicts the core positioning. Acceptable to prototype the *product* experience; hard to justify as the shipped architecture for a privacy-first app.

**The sharpest tradeoff for the ADR:** _Do you need to capture meetings the user is NOT physically attending on their machine?_
- **No** → on-device capture wins decisively (privacy + robustness + cost). The "relay" question largely dissolves.
- **Yes** → you're forced into a bot, and then the real choice is **self-hosted Vexa/Attendee (privacy, but you operate infra + inherit platform churn)** vs. **hosted Recall (turnkey, but audio leaves the device)**. There is no option that is simultaneously turnkey, bot-based, AND keeps audio on-device — that tension is the decision.

My read: lead with on-device capture as the local-first default, and treat a self-hostable bot (Vexa) as the opt-in path for the "join a meeting for me" use case, explicitly flagged as routing audio through infrastructure the user controls.

---

## 8. Sources

- [Recall.ai Pricing](https://www.recall.ai/pricing) — official pricing page (dated Mar–May 2026): $0.50/hr recording, $0.15/hr transcription, no platform fee.
- [Recall.ai — New Pricing for 2026](https://www.recall.ai/blog/new-recall-ai-pricing-for-2026) — announces $0.70→$0.50 drop, storage terms; published 2026-03-10.
- [Recall.ai Meeting Bot API](https://www.recall.ai/product/meeting-bot-api) — platform coverage (Zoom/Teams/Meet/Webex/GoTo/Slack).
- [Recall.ai Desktop Recording SDK](https://www.recall.ai/product/desktop-recording-sdk) — local capture, no bot joins the call.
- [Recall.ai Desktop SDK docs](https://docs.recall.ai/docs/desktop-sdk) — local mic+system audio mixing, upload flow, compliance certs.
- [Recall.ai — How I built an in-house Google Meet bot](https://www.recall.ai/blog/how-i-built-an-in-house-google-meet-bot) — candid DIY difficulty writeup.
- [Recall.ai — Open Source Puppeteer Google Meet Bot](https://www.recall.ai/blog/puppeteer-google-meet-bot) — DIY approach + virtual audio capture.
- [Vexa.ai](https://vexa.ai/) — Apache-2.0 open-source relay, self-host, real-time diarized transcription; bots from $0.30/hr.
- [Vexa — Google Meet Transcription API](https://vexa.ai/product/google-meet-transcription-api) — headless-browser bot, Whisper local, self-host details.
- [Vexa Documentation](https://docs.vexa.ai/) — Vexa Lite single-container / GPU-free deploy.
- [Vexa GitHub (google_auth)](https://github.com/Vexa-ai/vexa_google_auth) — self-hosted multi-user Meet bot repo.
- [Attendee.dev](https://attendee.dev/) — open-source universal meeting bot, self-host-first.
- [Attendee GitHub (attendee-labs/attendee)](https://github.com/attendee-labs/attendee) — ~660 stars, v1.55.1 (2026-07-10); Zoom live, Meet/Teams roadmap; Django+Postgres+Redis; Deepgram transcription.
- [Zoom Developer Blog — Attendee + RTMS](https://developers.zoom.us/blog/realtime-media-streams-attendee/) — Attendee using Zoom Real-Time Media Streams (sanctioned path).
- [MeetingBaaS](https://www.meetingbaas.com/en) — hosted bot API, Zoom/Teams/Meet, WebSocket real-time, Speaking Bots.
- [MeetingBaaS On-Premises offer](https://www.meetingbaas.com/en/blog/on_prem_offer) — ~$5,500/mo base + $0.066/hr, SLA.
- [MeetingBaaS GitHub (meet-teams-bot)](https://github.com/Meeting-Baas/meet-teams-bot) — open-source bot components.
- [Skribby](https://skribby.io/) and [Skribby Pricing](https://skribby.io/pricing) — $0.35/hr bot, usage-based, 10+ transcription models.
- [Skribby — Meeting Bot API comparison 2026](https://skribby.io/blog/meeting-bot-api-comparison-2026) — Skribby vs Recall vs MeetingBaaS (vendor-authored, treat as directional).
- [MeetStream — Recall.ai Alternatives: 6 Meeting Bot APIs Compared](https://meetstream.ai/blog/recall-ai-alternatives/) — comparison incl. real-time/self-host columns (vendor-authored).
- [MeetStream — Build a Google Meet Bot from Scratch](https://meetstream.ai/blog/build-google-meet-bot-from-scratch/) — DIY approach walkthrough.
- [Meetily — Self-Hosted Meeting Transcription: 10 OSS Tools (2026)](https://meetily.ai/blog/best-self-hosted-meeting-transcription-tools-2026) — landscape of local/OSS tools.
- [Meetily — Bot-Free Meeting Transcription 2026](https://meetily.ai/blog/bot-free-self-hosted-meeting-transcription/) — on-device system-audio capture, no bot, offline/local.
- [screenappai/meeting-bot (GitHub)](https://github.com/screenappai/meeting-bot) — universal DIY bot, Docker + chrome-CDP sidecars, production-grade OSS.
- [Ritika-Das/Google-Meet-Bot (GitHub)](https://github.com/Ritika-Das/Google-Meet-Bot) — Puppeteer Meet bot demo (early-2025 selectors).
- [UC Today — Microsoft, Zoom, Google tighten meeting-bot controls](https://www.uctoday.com/security-compliance-risk/ai-meeting-bots-controls-microsoft-zoom-google/) — anti-bot policy tightening (2025–2026).
- [Windows Forum — Teams 2026 Bot Detection / lobby approval](https://windowsforum.com/threads/microsoft-teams-2026-bot-detection-lobby-approval-as-ai-assistant-governance.432162/) — Teams bot-detection rollout.
- [Palo Alto Networks — Stopping Unauthorized AI Bots in the Boardroom](https://www.paloaltonetworks.com/blog/sase/silent-intruders-stopping-unauthorized-ai-bots-in-the-boardroom/) — security framing of meeting bots.
- [Nylas — Best APIs for recording Zoom/Teams/Meet](https://www.nylas.com/blog/best-apis-for-recording-zoom-microsoft-teams-google-meet/) — Nylas Notetaker + per-platform recording constraints.
- [Sacra — Recall.ai revenue/funding profile](https://sacra.com/c/recall-ai/) — incumbent maturity/scale context.
