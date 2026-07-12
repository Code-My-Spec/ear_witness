# EarWitness.Bots.Runner

Drives one bot session end to end — joins the target meeting under the session's display name, captures audio while the meeting is underway, leaves on completion or recall, and hands the captured audio off to `EarWitness.Recordings` as a `"bot"`-sourced recording. Reports every status transition back through `EarWitness.Bots` rather than writing to storage itself.

## Type

module

## Functions

### start_link/1

Starts a supervised process for a freshly dispatched bot session and begins the join sequence against the meeting platform. Called by `EarWitness.Bots.dispatch_bot/1` immediately after a session is persisted.

```elixir
@spec start_link(BotSession.t()) :: {:ok, pid()} | {:error, term()}
```

**Process**:
1. Start a process bound to the given session's id.
2. Asynchronously attempt to join the meeting at `session.meeting_url` under `session.display_name`.
3. On successful join, call `EarWitness.Bots.mark_recording/1` and begin capturing audio.
4. On a waiting-room rejection or other join failure, call `EarWitness.Bots.fail_bot_session/2` with a human-readable reason (e.g. mentioning "waiting room") and stop.
5. When the meeting ends on its own, leave, hand the captured audio to `EarWitness.Recordings`, call `EarWitness.Bots.complete_bot_session/2` with the resulting recording id, and stop.

**Test Assertions**:
- starts a process bound to the given session
- transitions the session to "recording" once join succeeds
- transitions the session to "failed" with a reason naming the waiting-room rejection when the meeting's waiting room declines the bot
- hands captured audio to Recordings sourced as "bot" and transitions the session to "completed" once the meeting ends naturally
- a completed session's audio and transcript are retained in the local library independent of the relay

### recall/1

Signals a session's running process to leave its meeting immediately rather than waiting for it to end on its own. Called by `EarWitness.Bots.recall_bot/1` after it has already marked the session recalled.

```elixir
@spec recall(integer()) :: :ok | {:error, :not_found}
```

**Process**:
1. Look up the running process for the given session id; return `{:error, :not_found}` if none is running.
2. Tell it to leave the meeting immediately and stop, discarding no audio captured so far.

**Test Assertions**:
- leaves the meeting and stops the process for a session that is actively recording
- returns {:error, :not_found} when no process is running for the given session id

## Dependencies

- EarWitness.Bots
- EarWitness.Bots.BotSession
- EarWitness.Recordings
