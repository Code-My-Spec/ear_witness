# EarWitness.Audio

Live audio capture infrastructure — Membrane pipelines for microphone and
system-audio-tap capture, capture-source and consent-policy selection, and
live level metering for the recording UI. `EarWitness.Recordings` composes
this context for live capture; this context has no knowledge of recordings,
files, or the library — it only runs and reports on capture sessions. It
never joins a meeting and never depends on `EarWitness.Bots` — capture reads
local audio devices only.

## Type

context

## Functions

### list_capture_sources/0

Lists the capture sources available on this machine — microphone input
devices and the system-audio tap — for the settings UI to offer as choices
and to decide whether to show guided tap setup.

```elixir
@spec list_capture_sources() ::
        [%{type: :microphone | :system_audio_tap, id: term(), name: String.t(), available: boolean()}]
```

**Process**:
1. Ask `EarWitness.Audio.Pipeline` for the microphone input devices (in the
   `:fixture` test environment this returns fixture devices instead of
   querying portaudio; see `config :ear_witness, :capture_source`).
2. Ask `EarWitness.Audio.Tap` whether the system tap is set up on this
   machine.
3. Merge both into one list of capture sources, each tagged with its type
   and availability.

**Test Assertions**:
- returns an empty microphone list when the input backend reports no
  devices (story 860, criterion 7325)
- includes a `:system_audio_tap` source when `:capture_source` is
  `:fixture` (story 861, criterion 7333)
- marks `:system_audio_tap` unavailable when `EarWitness.Audio.Tap` reports
  the tap is not set up (story 861, criterion 7338)

### get_active_capture_source/0

Returns the capture source the next call to `start_capture/1` will use.

```elixir
@spec get_active_capture_source() :: :microphone | :system_audio_tap
```

**Process**:
1. Read the persisted selection; default to `:microphone` if none has ever
   been made.

**Test Assertions**:
- returns `:microphone` before any selection has been made
- returns the source most recently persisted by `set_active_capture_source/1`,
  including when read from a freshly started session (story 861, criterion
  7333)

### set_active_capture_source/1

Persists the capture source that future captures will use, refusing sources
that are not actually available rather than silently activating them.

```elixir
@spec set_active_capture_source(:microphone | :system_audio_tap) ::
        {:ok, :microphone | :system_audio_tap} | {:error, :source_unavailable}
```

**Process**:
1. Check the requested source against `list_capture_sources/0`.
2. If unavailable, return `{:error, :source_unavailable}` and leave the
   previously active source untouched.
3. If available, persist the selection and return `{:ok, source}`.

**Test Assertions**:
- persists `:system_audio_tap` as active when the tap is available (story
  861, criterion 7333)
- returns `{:error, :source_unavailable}` and leaves the previous source
  active when the tap is not set up on this machine, instead of activating
  it (story 861, criterion 7338)

### get_consent_policy/0

Returns the recording consent/notification policy currently governing
capture.

```elixir
@spec get_consent_policy() :: :silent | :notify | :announce
```

**Process**:
1. Read the persisted policy; default to `:notify` if none has ever been
   chosen, so a fresh install cannot silently record without notice.

**Test Assertions**:
- returns `:notify` on a fresh install where no policy has ever been chosen
  (story 867, criterion 7376)
- returns the policy most recently persisted by `set_consent_policy/1`,
  including when read from a freshly started session (story 867, criterion
  7371)

### set_consent_policy/1

Persists the recording consent/notification policy that will govern future
captures.

```elixir
@spec set_consent_policy(:silent | :notify | :announce) ::
        {:ok, :silent | :notify | :announce}
```

**Process**:
1. Persist the chosen policy.

**Test Assertions**:
- `get_consent_policy/0` returns `:notify` immediately after
  `set_consent_policy(:notify)` (story 867, criterion 7371)

### list_consent_policies/0

Lists the three selectable consent policies with a plain-language
explanation of each, plus the shared not-legal-advice disclaimer, for the
settings UI to render next to every option.

```elixir
@spec list_consent_policies() ::
        {[%{id: :silent | :notify | :announce, explanation: String.t()}], disclaimer :: String.t()}
```

**Test Assertions**:
- returns exactly `:silent`, `:notify`, and `:announce`, each with a
  non-empty explanation (story 867, criterion 7374)
- returns a non-empty disclaimer stating this is not legal advice (story
  867, criterion 7374)

### start_capture/1

Starts live capture on the active capture source under the active consent
policy, writing to `path`. Refuses to start — and keeps no audio — when
the active policy's conditions aren't met or no input device is available.

```elixir
@spec start_capture(path :: Path.t()) ::
        {:ok, %{ref: reference(), channels: [:microphone | :system_audio], notice: :none | :shown | :delivered}}
        | {:error, :no_input_device | :notice_undelivered | :source_unavailable}
```

**Process**:
1. Resolve the active capture source and consent policy.
2. Consult `EarWitness.Audio.ConsentPolicy` to authorize the capture under
   the active policy: `:silent` authorizes unconditionally; `:notify`
   authorizes and flags that the UI should show a notice; `:announce`
   attempts to deliver an audible notice synchronously and only authorizes
   once delivery is confirmed.
3. If authorization fails, return `{:error, :notice_undelivered}` and start
   no pipeline.
4. Confirm the active source has an available device via
   `EarWitness.Audio.Pipeline` / `EarWitness.Audio.Tap`; if not, return
   `{:error, :no_input_device}` or `{:error, :source_unavailable}` and start
   no pipeline.
5. Start the Membrane pipeline for the resolved source(s) — microphone
   alone, or microphone mixed with the system-audio tap — writing to
   `path`, and return `{:ok, capture}` describing the channels captured and
   the notice shown, if any.

**Test Assertions**:
- returns `{:error, :no_input_device}` and starts no pipeline when the
  input backend reports no devices (story 860, criterion 7325)
- returns `{:ok, capture}` with `channels: [:microphone]` when the silent
  policy is active and microphone is the source (story 861, criterion
  7336)
- returns `{:ok, capture}` with `channels: [:microphone, :system_audio]`
  when the system audio tap is the active source (story 861, criterion
  7334)
- returns `{:error, :notice_undelivered}` and starts no pipeline when the
  announce policy's notice fails to deliver (story 861, criterion 7337;
  story 867, criteria 7373, 7375)
- returns `{:ok, capture}` with `notice: :delivered` only once the
  announce policy's audible notice is confirmed delivered (story 867,
  criterion 7372)
- returns `{:ok, capture}` with `notice: :shown` when the notify policy is
  active, for the recording UI's notice affordance (story 867, criterion
  7376)

### stop_capture/1

Stops a running capture, finalizes the file on disk, and returns the
capture's final channel list for `EarWitness.Recordings` to persist.

```elixir
@spec stop_capture(reference()) ::
        {:ok, %{ref: reference(), channels: [:microphone | :system_audio], path: Path.t()}}
```

**Process**:
1. Stop the Membrane pipeline identified by `ref`.
2. Flush and close the output file so it is immediately readable.
3. Return the capture's channel list and file path unchanged from
   `start_capture/1`.

**Test Assertions**:
- finalizes the output file so the resulting recording is immediately
  usable (story 860, criterion 7324)
- returns the same channel list `start_capture/1` reported, so callers can
  tell microphone-only captures from microphone-plus-system-audio captures
  (story 861, criterion 7334)

### subscribe_levels/1

Subscribes the caller to live input-level updates for a running capture,
for the recording UI's level meter. Updates arrive as ordinary messages the
LiveView re-renders on, never as something a BDD spec subscribes to
directly.

```elixir
@spec subscribe_levels(reference()) :: :ok
```

**Process**:
1. Subscribe the calling process to the PubSub topic for this capture's
   peak-level broadcasts, published by `EarWitness.Audio.PeakDetector`
   while the pipeline runs.

**Test Assertions**:
- the caller receives at least one `{:audio_level, ref, peak}` message
  while the capture identified by `ref` is running

## Dependencies

- EarWitness.Repo
- Phoenix.PubSub

## Fields

Persisted capture settings row read/written by `get_active_capture_source/0`,
`set_active_capture_source/1`, `get_consent_policy/0`, and
`set_consent_policy/1`. A singleton row, following the same pattern as the
project's existing local-settings storage — there is exactly one machine's
worth of settings, not one per user.

| Field                 | Type    | Required   | Description                                              | Constraints                                          |
| --------------------- | ------- | ---------- | ---------------------------------------------------------- | ----------------------------------------------------- |
| id                    | integer | Yes (auto) | Primary key                                               | Auto-generated                                       |
| active_capture_source | string  | Yes        | The capture source `start_capture/1` uses next            | One of `microphone`, `system_audio_tap`; default `microphone` |
| consent_policy        | string  | Yes        | The consent/notification policy governing capture         | One of `silent`, `notify`, `announce`; default `notify` |

## Components

### EarWitness.Audio.Pipeline

Membrane pipeline that captures the selected input device(s) — microphone
and/or the system-audio tap, mixed together when both are active — into a
recording file. Honors the `:capture_source` test seam
(`config :ear_witness, :capture_source`), substituting fixture WAV bytes
for real portaudio device I/O.

### EarWitness.Audio.Tap

System audio tap integration — discovers/creates the OS virtual device
(macOS Core Audio process tap, Windows WASAPI loopback) that exposes output
audio for capture, and reports whether it is set up on this machine.

### EarWitness.Audio.ConsentPolicy

Pluggable recording consent/notification behavior (`:silent` | `:notify` |
`:announce`), consulted before any capture starts. Owns delivery of the
`:announce` policy's audible notice and reports whether it succeeded.

### EarWitness.Audio.PeakDetector

Live input level metering for the recording UI — computes peak levels from
the running pipeline and broadcasts them over PubSub for the capturing
LiveView to re-render against.
