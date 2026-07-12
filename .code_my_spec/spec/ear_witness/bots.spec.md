# EarWitness.Bots

Meeting bots for meetings the user can't attend — dispatch a bot that joins a call as a visible participant, records it, and deposits the audio into the recordings library for the normal transcription/diarization pipeline.

## Type

context

## Dependencies

- EarWitness.Recordings

## Functions

### dispatch_bot/1

Creates a new bot session for a pasted meeting link and starts a `Runner` to join, record, and report back. The session is immediately visible with status `"dispatched"`; joining happens asynchronously.

```elixir
@spec dispatch_bot(map()) :: {:ok, BotSession.t()} | {:error, Ecto.Changeset.t()}
```

**Process**:
1. Build a `BotSession` changeset from the given attrs (at minimum `meeting_url`), defaulting `display_name` to the fixed product identity `"EarWitness Notetaker"` and `status` to `"dispatched"`.
2. Insert the record.
3. On success, start a `Runner` process for the session and broadcast the new session to subscribers.
4. Return `{:ok, session}`, or `{:error, changeset}` when `meeting_url` is missing or invalid.

**Test Assertions**:
- persists a session for the given meeting_url with status "dispatched"
- defaults display_name to "EarWitness Notetaker" without a display_name input
- starts a Runner process for the new session
- broadcasts the new session to subscribers
- returns an error changeset when meeting_url is blank

### list_bot_sessions/0

Returns every dispatched bot session, most recent first, for the dispatch/monitor UI.

```elixir
@spec list_bot_sessions() :: [BotSession.t()]
```

**Process**:
1. Query all `BotSession` records ordered by `inserted_at` descending.

**Test Assertions**:
- returns an empty list when no bots have been dispatched
- returns dispatched sessions newest first

### recall_bot/1

Pulls a bot back out of its meeting before it would finish on its own.

```elixir
@spec recall_bot(integer()) :: {:ok, BotSession.t()} | {:error, :not_found | :not_recallable}
```

**Process**:
1. Look up the session by id; return `{:error, :not_found}` if it doesn't exist.
2. Return `{:error, :not_recallable}` if the session has already reached a terminal status (`"completed"`, `"recalled"`, `"failed"`).
3. Signal the session's running `Runner` to leave the meeting immediately.
4. Update the session's status to `"recalled"` and broadcast the change.

**Test Assertions**:
- transitions a dispatched or recording session to "recalled"
- signals the Runner process to leave the meeting
- returns {:error, :not_recallable} for a session that already completed, recalled, or failed
- a recalled session's recall action is no longer offered

### mark_recording/1

Marks a session as actively recording once the bot successfully joins the meeting.

```elixir
@spec mark_recording(integer()) :: {:ok, BotSession.t()} | {:error, :not_found}
```

**Process**:
1. Load the session and update its status to `"recording"`.
2. Broadcast the change to subscribers.

**Test Assertions**:
- transitions a dispatched session to "recording"
- broadcasts the status change to subscribers

### complete_bot_session/2

Called by the `Runner` once it has left the meeting and handed the captured audio to `EarWitness.Recordings`. Links the session to the resulting recording so it appears in the library, sourced as `"bot"`.

```elixir
@spec complete_bot_session(integer(), integer()) :: {:ok, BotSession.t()} | {:error, :not_found}
```

**Process**:
1. Load the session, set status to `"completed"`, and associate the given recording id.
2. Broadcast the change to subscribers.

**Test Assertions**:
- transitions a session to "completed" and links the resulting recording
- the linked recording is discoverable from the library sourced as "bot"

### fail_bot_session/2

Records that a bot session's join attempt failed, with a human-readable reason so the failure is reported rather than swallowed.

```elixir
@spec fail_bot_session(integer(), String.t()) :: {:ok, BotSession.t()} | {:error, :not_found}
```

**Process**:
1. Load the session, set status to `"failed"`, and store the given failure reason.
2. Broadcast the change to subscribers.

**Test Assertions**:
- transitions a session to "failed" and stores a reason naming what went wrong (e.g. a waiting-room rejection)
- a failed session remains visible in the list rather than disappearing

### subscribe/0

Subscribes the calling process to bot session status updates, so the monitor UI reflects dispatch, recording, completion, recall, and failure without polling.

```elixir
@spec subscribe() :: :ok | {:error, term()}
```

**Process**:
1. `Phoenix.PubSub.subscribe/2` on the bot sessions topic.

**Test Assertions**:
- the calling process receives a message when a session is dispatched, recorded, completed, recalled, or failed

## Components

### EarWitness.Bots.BotSession

A dispatched bot: target meeting URL, the fixed identifying display name the bot presents in the meeting, schedule, status (`dispatched | recording | completed | recalled | failed`), failure reason, and a reference to the resulting recording once complete.

### EarWitness.Bots.Runner

Drives one bot session end to end — joins the target meeting through the relay/vendor integration under a clearly identifying display name, captures audio while the meeting is underway, leaves on completion or recall, and hands the captured audio off to `EarWitness.Recordings` as a `"bot"`-sourced recording. Reports every status transition back through `EarWitness.Bots` (`mark_recording/1`, `complete_bot_session/2`, `fail_bot_session/2`) rather than writing to storage itself.
