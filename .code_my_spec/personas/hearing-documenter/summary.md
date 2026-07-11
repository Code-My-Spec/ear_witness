# Dana the Hearing Documenter

## Role

Tenant advocate / civic observer who attends public tenant-board and housing-court
proceedings (in person or via the tribunal's Zoom stream) and turns them into
usable written records. Not a lawyer or court employee — a motivated citizen,
organizer, or freelance journalist doing accountability documentation that no
institution is doing for them. Seeded by EarWitness's founding customer, who
wanted to attend a tenant board's public landlord–tenant dispute proceedings and
transcribe them because they are public in name but published nowhere.

A secondary flavor of the same persona is the founder's own use: a consultant /
builder in daily meetings who wants a private, searchable record of every
conversation without a notetaker bot joining the call.

## Goals

- Turn public-but-unpublished proceedings into searchable, quotable transcripts
  (from lawfully obtained audio: official recordings ordered from the tribunal,
  streams they are permitted to capture, or their own in-room recording where
  rules allow it).
- Build a body of evidence over dozens of hearings — patterns of outcomes, not
  just one case — on a volunteer/shoestring budget.
- Keep sensitive material (tenants' personal circumstances, sources) on their
  own machine, never on a third-party server.
- Spend hearing time listening, not typing; manual note forms lose detail and
  verbatim quotes.

## Pain Points

- Official records are inaccessible: tribunal hearing recordings are not
  public, must be ordered per-case for a fee, and their existence/quality is
  not guaranteed; systematic eviction-court data is missing tenant-side detail
  entirely.
- Court-watch practice today is handwritten notes typed into forms afterwards —
  slow, lossy, and unable to capture verbatim statements.
- Cloud transcription at documentation volume is unaffordable: hours of
  hearings per week at ~$3.40–15/hr of audio adds up fast on a volunteer
  budget, and free tiers cap at minutes per month.
- Cloud notetaker bots are a legal/ethical minefield (consent lawsuits,
  recording after the call ended) and are simply not an option inside a
  tribunal Zoom room — observers are barred from screenshots/recording, so any
  tool that announces itself or uploads audio is disqualifying.
- Long recordings (2–4 hour hearing blocks) choke consumer tools with
  per-file minute limits.

## Context

- Works on a personal laptop; no IT department, no procurement. Downloads a
  desktop app and expects it to work offline.
- Audio sources are messy: ordered official recordings (various formats),
  speaker-phone Zoom audio, in-room recordings from a phone.
- Multiple speakers per recording (adjudicator, landlord, tenant, interpreters)
  — needs to tell who said what for a quote to be usable.
- Operates inside recording rules: hearings are public and observable, but
  observer recording is often restricted; the workflow must accommodate
  transcribing official/ordered recordings, not covert capture.
- The meeting-user flavor: back-to-back Zoom/Meet calls on the same laptop,
  confidential client conversations, no bot allowed in the room.

## Decision Drivers

- **Privacy first**: audio and transcripts never leave the device. This is the
  reason to choose a local whisper.cpp app over Otter/Rev/Granola, per the
  founding customer and the founder (PM intake), and matches expert guidance
  that for sensitive material only local tools are appropriate.
- **No bot, no upload**: captures/transcribes from audio directly; nothing
  joins the call, nothing phones home.
- **Cost**: effectively unlimited transcription for free after install vs.
  per-minute cloud pricing; volume users hit cloud limits immediately.
- **Handles long audio**: multi-hour files must not be truncated or split by
  arbitrary caps.
- Accuracy on real-world audio and speaker attribution beat fancy AI summary
  features; the transcript itself is the product.

## Jobs to Be Done

- When I get the recording of a public hearing, I want an accurate local
  transcript with speakers identified, so I can publish/organize around what
  was actually said without exposing anyone's data to a cloud service.
- When I'm in back-to-back meetings, I want every conversation transcribed and
  searchable on my own machine, so I can recall commitments without a bot
  joining my calls.

## Evidence

Claims above trace to these source clusters (full citations in sources.md):

- *Hearings are public but records are not published; recordings are
  fee-per-request and not guaranteed*: Tribunals Ontario LTB recording-request
  instructions and public-access guideline; SOLO "Observing LTB Hearings";
  Steps to Justice eviction-hearing guide. (3 sources)
- *Systematic documentation gap in eviction/housing proceedings*: GAO report on
  national eviction data limits; New America on what court eviction data
  doesn't capture; CHI 2024 paper on making eviction data actionable for
  housing justice. (3 sources)
- *Court watchers document by hand today and observer recording is
  restricted*: LA Public Press on immigration court watchers; Survived &
  Punished courtwatch toolkit; Advocates for Human Rights WATCH program;
  Digital Media Law Project on recording public meetings/hearings. (4 sources)
- *Privacy-sensitive professionals choose local Whisper tools*: Freedom of the
  Press Foundation transcription-security guide; GIJN reprint; MakeUseOf on
  offline interview transcription with Buzz; WhisperScript positioning for
  journalists/lawyers. (4 sources)
- *Cloud notetaker bots face a consent backlash*: NPR on the Otter.ai
  class-action; UC Today on the bot that kept listening; Reworked/Mac Murray &
  Shuster on meeting-bot consent liability. (4 sources)
- *Cost of cloud transcription at volume*: Sonix's Otter pricing analysis
  (~$3.40/hr on Pro); Rev pricing ($0.25/min AI); VOCAP/ConvertAudioToText 2026
  pricing comparisons; free tiers capped in minutes. (4 sources)
- *Seed users*: PM intake interview 2026-07-11 — founding customer (tenant
  board proceedings) and founder (own meetings); drivers named: privacy,
  no-bot, cost. (1 primary source, corroborated by the public clusters above)
