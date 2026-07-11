# Legality of Recording Meetings Without Participant Notification

Research notes for responding to the Reddit thread question about EarWitness recording
audio without notifying other meeting participants. Compiled 2026-07-11. Not legal advice.

**TLDR:** Recording a meeting with no notification to participants is illegal in a
significant chunk of jurisdictions, and there is active litigation right now over exactly
this product category (AI notetakers). The tool is legal to build and sell; using it to
record others without notice is illegal in all-party consent jurisdictions, and that
responsibility sits with the user.

## US legal landscape

- **Federal law (Wiretap Act / ECPA)** is one-party consent: if the person running the
  recorder is a participant in the conversation, that's legal federally.
- **12–13 states are "all-party consent"** — California, Connecticut, Delaware, Florida,
  Illinois, Maryland, Massachusetts, Montana, New Hampshire, Oregon, Pennsylvania, and
  Washington (sources vary slightly on the count). In those states, recording without
  every participant's consent is a crime — in some states a felony (e.g., up to 7 years
  in Pennsylvania) — and several also allow civil suits by the recorded parties.
- **Interstate calls take the strictest rule in practice.** If any participant is in
  California, courts generally apply California's all-party rule. Since users can't know
  where remote participants are sitting, the safe operating assumption for any product
  is all-party consent.
- **A bot merely being visible in the participant list is not legally sufficient consent
  anywhere** — informed agreement is the bar, not mere awareness. EarWitness doesn't even
  have a visible bot (it taps the local audio device), which makes silent recording
  *less* defensible in an all-party state, not more.

## The Otter.ai litigation — directly on point

Four consolidated class actions against Otter.ai (*In re Otter.AI Privacy Litigation*,
N.D. Cal., case 5:25-cv-06911, consolidated Oct 2025) allege its OtterPilot notetaker
violates the federal Wiretap Act and the California Invasion of Privacy Act (CIPA) by
recording non-users who never consented. A motion-to-dismiss ruling was pending as of
mid-June 2026.

1. **Liability targets the vendor, not just the user.** The theory is that Otter itself
   is an eavesdropping third party because audio goes to its servers and is used to
   train models. The plaintiffs' bar is going after AI notetaker companies directly.
2. **This cuts in EarWitness's favor architecturally.** Local whisper.cpp transcription
   means no audio leaves the machine and the vendor never intercepts anything, which
   substantially weakens the "vendor as interceptor" theory driving the Otter suits.
   It does NOT help the user, who is still on the hook under state consent laws.

## Outside the US

- **GDPR (EU/UK):** a recording or transcript containing an identifiable person's voice
  is personal data. Participants must be notified before recording starts; silence or
  continued participation doesn't count as consent, and merely announcing "this call is
  recorded" isn't sufficient. "Legitimate interests" can sometimes substitute for consent
  in internal business contexts.
- **Canada:** informed consent, including the purpose of the recording, is required.

## Practical takeaways for EarWitness

- Put consent responsibility on the user in the ToS (standard for the category).
- Prompt/remind the user to announce recording; consider an optional auto-announcement
  or a consent checkbox before starting a session — a feature, not just a disclaimer.
- Emphasize on-device processing as a genuine privacy differentiator vs. cloud notetakers.
- Before commercial launch, get a privacy lawyer to review the ToS language.

## Sources

- [AI Meeting Recording Laws by State (Recording Law, 2026)](https://www.recordinglaw.com/us-laws/ai-meeting-recording-laws/)
- [Two-Party Consent States 2026 Guide (Recording Law)](https://www.recordinglaw.com/party-two-party-consent-states/)
- [New Wave of Privacy Litigation Targets Otter.ai (National Law Review)](https://natlawreview.com/article/take-note-new-wave-privacy-litigation-targets-ai-notetaker-otterai)
- [MoFo: Wiretapping Theories Reach AI Notetakers (Morrison Foerster)](https://www.mofo.com/resources/insights/260220-a-mofo-privacy-minute-q-a-wiretapping-theories-reach-ai-notetakers)
- [Otter.ai Privacy Class Action status (openclassactions.com)](https://openclassactions.com/lawsuits/otter-ai-privacy-wiretap-class-action.php)
- [Fisher Phillips: 7 Steps Businesses Should Take on AI Notetakers](https://www.fisherphillips.com/en/insights/insights/new-lawsuit-highlights-concerns-about-ai-notetakers)
- [NPR: Lawsuit claims Otter secretly records private chats](https://www.npr.org/2025/08/15/g-s1-83087/otter-ai-transcription-class-action-lawsuit)
- [GDPR call recording compliance (Dialpad)](https://www.dialpad.com/blog/call-recording-gdpr-compliance/)
- [GDPR meeting recording guide (recordmeeting.com)](https://recordmeeting.com/blog/gdpr-meeting-recording-guide)
- [Global phone recording laws incl. Canada (Noota)](https://www.noota.io/en/phone-recording-laws-guide)
