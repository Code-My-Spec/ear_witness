# Marcus the Meeting-Heavy Builder

## Role

Founder / independent consultant whose working day is a wall of calls —
client sessions, sales conversations, standups, advisory chats. He is both
the product's builder-user (EarWitness's founder fits this persona) and its
broader market: the professional whose conversations ARE the work product,
who signs NDAs, and who already uses an AI assistant (Claude or similar)
daily for everything else.

## Goals

- Never lose a decision or commitment made in a call: the average knowledge
  worker spends ~392 hours/year in meetings and reports that fatigue and
  volume degrade recall and follow-through.
- Have every conversation transcribed, attributed, and searchable without
  doing anything per-meeting.
- Put his AI assistant to work on that history — "what did we decide about
  X?", meeting summaries, follow-up drafts — via the tools he already uses
  (MCP clients like Claude Code/Desktop).
- Stay inside client NDAs: no third-party service processing confidential
  client strategy, no visible bot alarming a client mid-negotiation.

## Pain Points

- Cloud notetakers create legal exposure he can't accept: recordings and
  transcripts on vendor servers may violate NDAs, waive privilege, and
  trigger wiretap/consent laws; law and compliance firms now advise banning
  them from sensitive meetings outright.
- The bot in the participant list is a client-trust problem — the client
  agreed to talk to him, not to an AI vendor's recorder.
- Back-to-back scheduling means no time to take or clean up notes manually;
  action items evaporate ("meeting recovery syndrome," 76% report feeling
  drained on heavy-meeting days).
- His assistant is blind to his richest data source: conversations. Copy-
  pasting transcripts into a chat window is the current workaround.

## Context

- Personal Mac (and sometimes Windows), no IT department; installs his own
  tools. Comfortable with technical setup but expects defaults to work.
- Calls happen on Zoom/Meet/Teams; some in-person. He is usually IN the
  meeting (audio tap use case); occasionally he can't attend and would send
  a visible bot instead.
- Already runs MCP-based tooling daily — the MCP ecosystem passed 10,000+
  public servers in 2026 and is the standard way his assistant reaches
  tools, so "EarWitness as an MCP server" matches his existing workflow.
- Subject to one-party/two-party consent laws depending on who he calls;
  needs the recording behavior to be a deliberate, configurable choice.

## Decision Drivers

- **Confidentiality is contractual, not preferential**: NDA exposure from
  cloud processing is the disqualifier for Otter-class tools; on-device
  capture and transcription removes the third party entirely.
- **No bot for meetings he attends**: capture must be invisible to the
  meeting (system audio tap) while staying lawful (consent policy).
- **Assistant-native**: read/search/summarize over stdio MCP with no
  network port beats any built-in AI feature; he wants HIS assistant, not
  the vendor's.
- **Zero per-meeting friction**: local transcription with no per-minute
  fees at his call volume.

## Jobs to Be Done

- When a client asks "didn't we agree to…?", I want to search my own call
  history and quote the exact moment, so disputes end in seconds.
- When my week is back-to-back, I want my assistant to brief me from
  yesterday's calls, so nothing I promised slips.
- When a meeting happens without me, I want a visible bot to bring the
  recording home into the same library, so my history stays complete.

## Evidence

Claims trace to these source clusters (full citations in sources.md):

- *Meeting overload degrades recall and follow-through*: SpeakWise meeting
  overload and meeting fatigue statistics compilations (392 hrs/yr, 76%
  drained, 51% overtime); Cosmos on back-to-back fatigue; AgilityPortal on
  meetings preventing execution. (4 sources)
- *Cloud notetakers are an NDA/privilege/consent liability for
  professionals*: Smith Law "The Silent Guest in Your Meetings"; Coblentz
  "It's Okay to Say No to AI Notetaking"; DataGrail on legal exposure;
  Duane Morris on privacy/privilege pitfalls; McLane Middleton on legal
  compliance; KenzNote consultant guide on the "bot problem" and NDA
  scope. (6 sources)
- *Consent laws make recording behavior a policy decision*: Bryan Driscoll
  on wiretap exposure; LegalSoul on one-party vs two-party consent;
  2Civility on client-meeting ethics. (3 sources)
- *AI assistants reach personal tools via MCP as the standard*: Anthropic's
  MCP introduction; WorkOS 2026 MCP guide; DigitalApplied MCP adoption
  statistics (10k+ public servers, Linux Foundation); ChatForest state of
  the ecosystem; Truthifi on agents connecting to personal data. (5
  sources)
- *Seed user*: PM intake 2026-07-11 — the founder is this persona ("I would
  also use it on all of my meetings"; wants tap capture, Otter-style
  editor, and "MCP tools that allow models to access my conversation
  data"). Proto persona: validate against additional real users before
  load-bearing GTM decisions.
