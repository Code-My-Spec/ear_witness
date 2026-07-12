# Meeting Bots — Microsoft Teams

_Research compiled 2026-07-12 for EarWitness (local-first Elixir desktop transcription app). Goal: get "both sides" of a Teams meeting into on-device transcription. The key open axis is **can this run on the end user's machine, or does it structurally require Azure + a Windows media stack / a cloud SaaS relay.**_

## 1. TL;DR

- **Microsoft's official "bot in the meeting" path (Graph cloud communications, application-hosted media) gives real-time, per-participant raw PCM audio — but it is structurally a cloud service.** It requires C#/.NET, a **Windows Server** guest OS, and deployment on **Azure**. As of March 2026 there is still **no Python, REST, or WebSocket** interface for real-time Teams audio, and none is on the near-term roadmap. This cannot run inside an Elixir desktop app on the user's machine.
- **Compliance recording bots** get the same clean per-participant media, are invited by the Teams backend via an admin **application access policy**, and are the "blessed" recording path — but they carry the **same Windows/C#/Azure media-stack requirement** plus tenant-admin setup. Not local either.
- **Hosted relay vendors (e.g. Recall.ai)** hide all of the above behind a REST/webhook API and run the bot in *their* cloud. You get real-time per-speaker audio over WebSocket, but it is a third-party SaaS the meeting audio flows through — the opposite of local-first.
- **The only genuinely local option is OS-level desktop capture (no bot joins the call)** — capture the system audio loopback (Teams' output = everyone else) + the microphone (the user). This runs on the user's Mac/Windows machine and needs no tenant admin, no Azure, no bot. Trade-off: you get **mixed** system audio, not clean separate participant streams; diarization must be done locally. Recall.ai's Desktop Recording SDK productizes exactly this.
- **Major 2026 headwind for bots:** Microsoft is rolling out **automatic external-bot detection** (MC1251206, roadmap 558107) May–July 2026 — third-party bots get flagged in the lobby as "unverified / suspected threats" and require organizer approval. This makes the "join as a bot" approaches increasingly fragile for a consumer product. The local desktop-capture approach sidesteps it entirely.

## 2. Approaches comparison

| Approach | Audio access | Real-time? | Runs on user's machine? | Maturity |
|---|---|---|---|---|
| **Graph application-hosted media bot** (Calls & Meetings, Bot Media SDK) | Raw PCM, per-participant, 50 frames/s (20 ms each) | Yes | **No** — C#/.NET, Windows Server, Azure | GA, mature; C#-only |
| **Graph service-hosted media bot** | No raw stream (IVR/prompts/tones only) | N/A | No | GA, mature |
| **Compliance recording bot** (policy-based) | Raw per-participant media | Yes | **No** — same Windows/C#/Azure stack + tenant policy | GA, mature; partner-oriented |
| **Hosted relay vendor** (Recall.ai etc.) | Per-speaker audio over WebSocket, 16 kHz | Yes | **No** — vendor cloud SaaS | GA, widely used |
| **Local desktop OS capture** (system loopback + mic, no bot) | Mixed system audio + local mic; **not** per-participant at OS level | Yes | **Yes** — Mac/Windows native/Electron/Tauri | GA via Recall Desktop SDK; DIY feasible |
| **Browser automation** (drive Teams web client, join, scrape audio) | Tab/system audio (mixed); brittle | Yes | Partially (needs headless browser infra) | Low; unofficial, ToS-risky, breaks often |

## 3. Official APIs / SDKs in detail

### Microsoft Graph cloud communications (Calls & Online Meetings)
The official way to put a bot **into** a Teams call/meeting. Two media-hosting models (Microsoft Learn, "Choose a media hosting option", doc dated 2024-11-07, page updated 2025-08-06):

- **Service-hosted media (remote):** media processing offloaded to Microsoft's Real-time Media Platform. Good for IVR: play prompts, detect tones, record short clips. **Does not give you a live raw stream of participant audio.** Lighter weight, more language flexibility.
- **Application-hosted media (local to the bot):** *"direct access to media streams"* for recording/transcription/translation/sentiment. This is what EarWitness-style transcription needs. Requires the **`Microsoft.Graph.Communications.Calls.Media`** .NET library.

**Hard requirements for application-hosted media** (Microsoft Learn, "Build Application-hosted Media Bots"):
- **C# and .NET only.** *"You can't use C++ or Node.js APIs to access real-time media."* No Python. .NET 6.0 is supported (so modern .NET / .NET Core works, not just legacy .NET Framework).
- **Windows Server guest OS** for production, deployed on **Azure** (Cloud Service, Service Fabric + VMSS, IaaS VM, or AKS). On-prem Windows Server allowed only for dev/test.
- VM needs ≥2 CPU cores (Azure Dv2-series recommended); bot must be **stateful**.
- Audio delivery: **50 audio frames/second, 20 ms each**, per participant, so you can run streaming STT as audio arrives. Codecs (SILK, G.722 audio; H.264 video) handled by the platform behind a socket-like API.

**Explicitly confirmed gap (as of March 2026):** multiple Microsoft Q&A answers state there is **no Python SDK, no REST, and no WebSocket** interface for joining a Teams meeting and receiving real-time audio, and no alternative-language support announced on the near-term roadmap. The Windows/C# media stack is still mandatory in 2026.

### Compliance recording (policy-based) — Microsoft Learn "Microsoft Teams compliance recording (third-party)"
- A registered Entra ID **application instance** is paired with a **compliance recording policy** (`New-CsTeamsComplianceRecordingPolicy` + `New-CsApplicationAccessPolicy` via the MicrosoftTeams PowerShell module). When a policy-covered user joins any call/meeting, the **Teams backend automatically invites the bot** to capture audio/video/screen-share.
- Media access is the same raw-frame stream as application-hosted media, and it is the compliance-grade path (MiFID II, HIPAA, etc.). Modern .NET (6+) is now supported for these bots.
- **Same infrastructure constraint:** the media SDK still runs on the Windows/C#/Azure stack. Compliance recording changes *how the bot is invited and consented* (backend-invited via admin policy), not the media runtime.

### Samples / SDK repos
- `microsoftgraph/microsoft-graph-comms-samples` — LocalMediaSamples (application-hosted, incl. `PolicyRecordingBot`) and RemoteMediaSamples (service-hosted). All C#.
- Graph Communications Calling SDK + Bot Media SDK docs: microsoftgraph.github.io/microsoft-graph-comms-samples.

### Browser automation (unofficial)
Driving the Teams **web** client with a headless browser to join and scrape tab/system audio is technically possible but: mixed audio only, no per-participant separation, extremely brittle against Teams UI/DOM changes, needs hosted browser infrastructure (so not really "local & simple"), and is squarely in ToS-gray territory. Not recommended as a primary path; only relevant as a last resort.

## 4. Auth / tenant admin / application access policy

- **Azure AD (Entra) app registration** is required for any Graph calling bot. Graph calling APIs support both **application permissions** (e.g. `Calls.AccessMedia.All`, `Calls.JoinGroupCall.All`) and **Resource-Specific Consent (RSC)** permissions declared in the Teams app manifest (e.g. `Calls.JoinGroupCalls.Chat` for meeting-scoped join).
- **Application access policy** (`New-CsApplicationAccessPolicy`, MicrosoftTeams PowerShell) is a one-time, per-app tenant setup that authorizes a given Entra app to act on users' meetings. Compliance recording additionally needs a compliance recording policy assigned to users.
- **Tenant admin consent is unavoidable** for the official bot paths: application permissions require admin consent, and the access/recording policies are admin-only PowerShell operations. This is a poor fit for a consumer/prosumer desktop app whose users may not control (or want to involve) their Teams tenant admin.

## 5. Participant visibility & consent

- A Graph calling bot **appears as a participant** in the roster when it joins a call/meeting.
- **Recording consent:** you **cannot** persist media or derived data without first calling the **`updateRecordingStatus`** API and getting a success reply; you must also signal when recording ends. Microsoft's Terms of Use apply and legal compliance is on you.
- Teams shows a **recording/transcription notification banner**. Since **~28 May 2025**, participants get an explicit-consent prompt; those who decline stay in the meeting but **cannot unmute / share** — a hard product-experience consideration if the whole meeting is being captured.
- IT admins can **customize** the recording/transcription notification text + privacy URL (MC1194071; rollout early Jan → late Jan 2026).
- **Compliance recording bots** are consented differently: they are backend-invited under an admin policy, so they aren't subject to the new external-bot lobby gating (below).
- **NEW / critical — external bot detection (MC1251206, roadmap 558107, published 13 Mar 2026):** Teams now **detects and labels external meeting-assistant bots** attempting to join. Flagged bots appear in the lobby under a "Suspected threats / Unverified" section, separated from humans; the organizer must explicitly **admit, deny, or remove** them. A new Teams admin meeting policy controls handling (do-not-detect vs require-approval). **Rollout mid-May 2026 → mid-July 2026, on by default.** This materially degrades the reliability of any "join as a third-party bot" approach going forward.

## 6. Feasibility for a local-first desktop app (the key axis)

**The official Microsoft bot paths cannot run inside an Elixir desktop app on the user's machine.** They are structurally cloud services:
- Media runtime is **C#/.NET on Windows Server**, and Microsoft explicitly forbids C++/Node/Python for real-time media. An Elixir/BEAM process cannot receive the media frames; you'd need a separate Windows C# bot service.
- Production deployment is **Azure**-bound, the bot must be a publicly reachable, stateful, signalling-capable service (not a laptop behind NAT), and it needs **tenant admin** consent/policy. That is the opposite of local-first and zero-config.
- Even a self-hosted Windows box (allowed only for dev/test) doesn't make it "local to the end user" — it's still a server the user must operate and expose.

**What *can* run locally is OS-level desktop audio capture with no bot in the call:**
- Capture the **system audio loopback** (everything Teams plays out = all remote participants, mixed) plus the **microphone** (the local user), and feed both into on-device transcription. No bot joins, no roster entry, no tenant admin, no Azure, no Windows-media-stack requirement.
- On macOS this is `ScreenCaptureKit` (`SCStream` with `capturesAudio` for system audio and `captureMicrophone` for mic); on Windows it's WASAPI loopback. Streams arrive at different rates (e.g. 48 kHz stereo system vs 44.1/16 kHz mic) and need resampling/mixing. This aligns with EarWitness's existing native-audio direction (cf. the miniaudio/system-audio capture work already in flight).
- **Recall.ai's Desktop Recording SDK** productizes this exact approach: records Zoom/Teams/Meet **locally, with no meeting bot**, on Windows and Apple-Silicon Macs, integrates with Electron/Tauri/native apps, and yields audio + speaker-labeled transcripts + participant metadata. Their own "botless recorder from scratch" write-up confirms the mechanism is **system-audio + mic capture** and that at the OS level you get **mixed system audio, not separate per-participant streams** (their per-speaker labeling comes from additional meeting-metadata correlation, not from clean separated OS streams).
- **Local-capture limitation vs. bot paths:** bots give you **clean per-participant audio** (ideal for diarization); local system capture gives you **one mixed remote channel + your mic**, so speaker separation of the far side must be solved on-device (diarization) — consistent with EarWitness's known v1 diarization limitation.

## 7. Recency notes (what changed 2024–2026)

- **2024-11 → 2025-08:** media-hosting-options doc maintained; application-hosted media remains C#/.NET + Windows + Azure. **.NET 6+** now supported for both application-hosted and compliance recording bots (modern .NET, not just legacy Framework).
- **~28 May 2025:** explicit in-meeting **consent-to-record** prompts introduced; decliners lose unmute/share.
- **Early–late Jan 2026:** admins can **customize** recording/transcription notification text + privacy URL (MC1194071).
- **Feb–Mar 2026:** Microsoft Q&A reconfirms **no Python/REST/WebSocket** real-time Teams audio; Windows/C# media stack still required.
- **13 Mar 2026 (MC1251206):** **external bot detection & labeling** announced; **rollout mid-May → mid-July 2026, default on.** Third-party join-bots now face lobby gating/approval. This is the single most important 2026 change for anyone building a Teams join-bot.

## 8. Recommendation for EarWitness

1. **Primary: local OS-level desktop capture (no bot).** It is the only approach that fits "local-first Elixir desktop": runs entirely on the user's Mac/Windows machine, needs no Azure, no C#/Windows media service, no tenant admin, and is untouched by the 2026 external-bot crackdown. Capture system-audio loopback (remote side) + mic (local side); do diarization on-device (accepting the mixed-far-side limitation already documented for v1). This reuses the native-audio capture path EarWitness is already building.
2. **If clean per-participant streams become a hard requirement**, the realistic option is a **hosted relay vendor (Recall.ai)** rather than building a Graph media bot yourself — it removes the C#/Windows/Azure/tenant-admin burden. But it routes meeting audio through a third-party cloud, which conflicts with local-first positioning and privacy story. Treat as an optional "cloud connector," not the default.
3. **Do not** attempt to build a first-party Graph application-hosted / compliance-recording media bot for a desktop product: the C#-on-Windows-Server-in-Azure media stack, tenant-admin policy setup, and the tightening bot-lobby gating make it high-cost and strategically misaligned for a local-first app. Reserve it only for a future enterprise/tenant-deployed edition where an admin *wants* a compliance-grade recorder in their tenant.
4. Regardless of path, wire in **consent handling** (recording notifications; and for any bot path, `updateRecordingStatus`) — this is both legal and, post-May-2026, functionally required to avoid lobby rejection.

## 9. Sources

- [Choose a media hosting option (cloud communications API) — Microsoft Learn](https://learn.microsoft.com/en-us/graph/cloud-communications-media) — service- vs application-hosted media; raw-stream access; recording/updateRecordingStatus rule. Doc dated 2024-11-07, updated 2025-08-06.
- [Build Application-hosted Media Bots — Microsoft Learn](https://learn.microsoft.com/en-us/microsoftteams/platform/bots/calls-and-meetings/requirements-considerations-application-hosted-media-bots) — C#/.NET-only, Windows Server, Azure, ≥2 cores, stateful, .NET 6.
- [Real-time Media Call & Meeting for Bots — Microsoft Learn](https://learn.microsoft.com/en-us/microsoftteams/platform/bots/calls-and-meetings/real-time-media-concepts) — 50 frames/s, 20 ms, socket-like media API, codecs.
- [Bots for Teams Calls and Online Meetings (overview) — Microsoft Learn](https://learn.microsoft.com/en-us/microsoftteams/platform/bots/calls-and-meetings/calls-meetings-bots-overview) — capability overview.
- [Graph Communications Bot Media SDK docs](https://microsoftgraph.github.io/microsoft-graph-comms-samples/docs/bot_media/index.html) — application- vs service-hosted, stateful requirement.
- [Microsoft Q&A: bot joining Teams meetings & real-time audio (Python)](https://learn.microsoft.com/en-au/answers/questions/5807336/bot-joining-teams-meetings-and-receiving-real-time) — confirms no Python/REST/WebSocket for real-time audio (as of ~Mar 2026).
- [Microsoft Teams compliance recording (third-party) — Microsoft Learn](https://learn.microsoft.com/en-us/microsoftteams/teams-recording-compliance) — policy-based bot, backend-invited, raw media capture.
- [New-CsTeamsComplianceRecordingPolicy — Microsoft Learn](https://learn.microsoft.com/en-us/powershell/module/microsoftteams/new-csteamscompliancerecordingpolicy) — compliance recording policy cmdlet.
- [PolicyRecordingBot sample (graph-comms-samples)](https://github.com/microsoftgraph/microsoft-graph-comms-samples/blob/master/Samples/V1.0Samples/LocalMediaSamples/PolicyRecordingBot/README.md) — reference compliance recorder (C#).
- [Grant RSC permissions / Resource-specific consent — Microsoft Learn](https://learn.microsoft.com/en-us/microsoftteams/platform/graph-api/rsc/resource-specific-consent) — RSC vs Azure AD app permissions, application access policy.
- [Register Calls & Meetings Bot — Microsoft Learn](https://learn.microsoft.com/en-us/microsoftteams/platform/bots/calls-and-meetings/registering-calling-bot) — app registration + permissions for calling bots.
- [Custom in-meeting recording/transcription notification — Microsoft Learn](https://learn.microsoft.com/en-us/microsoftteams/recording-transcription-custom-message) — notification banner customization (MC1194071; Jan 2026).
- [MC1251206 — Identify external bots joining Teams meetings (Message Center)](https://mc.merill.net/message/MC1251206) — external bot detection/labeling; published 13 Mar 2026, roadmap 558107.
- [Teams Meetings to Block Third-Party Recording Bots — Office365 IT Pros, 16 Mar 2026](https://office365itpros.com/2026/03/16/third-party-recording-bots/) — lobby gating detail, rollout mid-May→mid-Jul 2026.
- [Microsoft wants to stop unwanted bots from entering Teams meetings — Help Net Security, 1 Jul 2026](https://www.helpnetsecurity.com/2026/07/01/microsoft-teams-bot-detection-and-protection/) — recent coverage of the rollout.
- [Recall.ai Microsoft Teams Meeting Bot API](https://www.recall.ai/product/meeting-bot-api/microsoft-teams) — hosted relay bot; per-speaker audio over WebSocket, real-time transcripts.
- [Recall.ai Desktop Recording SDK](https://www.recall.ai/product/desktop-recording-sdk) — **local, no-bot** capture on Windows + Apple-Silicon Mac; Electron/Tauri/native.
- [Recall.ai: "How I built a botless meeting recorder from scratch"](https://www.recall.ai/blog/how-i-built-a-botless-meeting-recorder-from-scratch) — confirms system-audio loopback + mic capture; OS-level yields **mixed** audio, not separate participant streams (example is macOS ScreenCaptureKit).
- [Recall.ai: Capturing recordings/transcripts without bots (blog)](https://www.recall.ai/blog/desktop-recording-sdk) — rationale: regulated industries reject in-meeting bots.

---
_Uncertainty / unverified: exact list of required Graph application permission strings varies by scenario and Microsoft renames them (RSC `Calls.JoinGroupCalls.Chat` vs app-permission `Calls.AccessMedia.All`) — verify against current Microsoft Learn before implementing. Recall.ai's exact Teams per-speaker separation mechanism on the Desktop SDK (vs the cloud Bot API) is not fully documented publicly; treat "clean per-participant streams locally" as unconfirmed._
