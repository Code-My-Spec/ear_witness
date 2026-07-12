# EarWitness.Bots.BotSession

A dispatched bot — target meeting URL, the fixed identifying display name it presents in the meeting, optional schedule, lifecycle status, failure reason, and a reference to the resulting recording once complete.

## Type

schema

## Fields

| Field | Type | Required | Description | Constraints |
| --- | --- | --- | --- | --- |
| id | integer | Yes (auto) | Primary key | Auto-generated |
| meeting_url | string | Yes | The pasted link to the meeting the bot is dispatched to | Non-blank |
| display_name | string | Yes | The fixed, non-configurable identity the bot presents inside the meeting, so it's never a stealth participant | Default: "EarWitness Notetaker" |
| status | string | Yes | Current lifecycle state | One of: dispatched, recording, completed, recalled, failed |
| scheduled_at | utc_datetime | No | When the bot should join, for a session scheduled in advance | Nil means join immediately on dispatch |
| failure_reason | string | No | Human-readable explanation of why the join failed (e.g. a waiting-room rejection) | Present only when status is failed |
| recording_id | integer | No | The recording produced once the bot completes its session | References recordings.id; present only when status is completed |

## Dependencies

- EarWitness.Recordings.Recording
