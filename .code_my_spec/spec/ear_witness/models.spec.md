# EarWitness.Models

Managed AI model files — the whisper model catalog (size/quality/language tradeoffs) and the diarization ONNX models. Downloads with verification and progress, storage under the app dir, and selection of the active model.

## Type

context

## Delegates

- list_models/0: EarWitness.Models.Catalog.list_models/0
- get_model/1: EarWitness.Models.Catalog.get_model/1
- default_model_id/0: EarWitness.Models.Catalog.default_model_id/0

## Functions

### get_active_model/0

Returns the model currently selected for transcription, or `nil` when nothing has been chosen yet.

```elixir
@spec get_active_model() :: EarWitness.Models.Catalog.model() | nil
```

**Process**:
1. Reads the persisted active-model selection from durable storage (not process state, so it survives an app restart).
2. Returns `nil` when nothing has ever been selected — the fresh-install state with no model downloaded yet.
3. Looks up and returns the full catalog entry for the persisted model id.

**Test Assertions**:
- returns nil on a fresh install with no model downloaded yet
- returns the full catalog entry for the id most recently passed to set_active_model/1
- still returns the same model after a simulated process/app restart

### set_active_model/1

Makes a model the app-wide active transcription model.

```elixir
@spec set_active_model(String.t()) :: {:ok, EarWitness.Models.Catalog.model()} | {:error, :unknown_model | :not_downloaded}
```

**Process**:
1. Looks up `model_id` in the catalog; returns `{:error, :unknown_model}` when it isn't a known id.
2. Confirms the model's file is present and checksum-verified on disk (bundled, or a previously completed download); returns `{:error, :not_downloaded}` otherwise — a partial or unverified file can never become active.
3. Persists `model_id` as the active model.
4. Broadcasts the change so subscribers (Setup/Settings LiveViews) can re-render.
5. Returns `{:ok, model}`.

**Test Assertions**:
- returns {:error, :not_downloaded} when the target model has no verified file on disk
- switching to a model that ships bundled with the app (no download required) succeeds
- get_active_model/0 returns the newly active model afterward
- get_active_model/0 no longer returns the previously active model afterward
- a subscriber (see subscribe/0) is notified of the change
- never leaves a partially-downloaded or checksum-failed model active, even if selection is retried mid-failure

### downloaded?/1

Reports whether a model's file is present and checksum-verified on disk.

```elixir
@spec downloaded?(String.t()) :: boolean()
```

**Process**:
1. Returns `true` for models that ship bundled with the app (the diarization ONNX models, and any bundled whisper tier) without consulting the Downloader.
2. Otherwise returns `true` only when the Downloader has recorded a completed, checksum-verified transfer for `model_id`.

**Test Assertions**:
- false for a downloadable model on a fresh install
- true for a model bundled with the app
- true once download_model/1 completes and its checksum verifies
- false while a download is in progress or after it has failed

### model_path/1

Resolves a model id to the absolute file path used to load it.

```elixir
@spec model_path(String.t()) :: {:ok, String.t()} | {:error, :not_downloaded}
```

**Process**:
1. Looks up `model_id`'s catalog entry to determine whether it ships bundled or must be downloaded.
2. For a bundled model, returns the packaged path shipped with the app.
3. For a downloadable model, returns `{:error, :not_downloaded}` unless downloaded?/1 is true; otherwise returns the verified file's path under the app directory.

**Test Assertions**:
- returns {:error, :not_downloaded} for a downloadable model that has not been downloaded
- returns {:ok, path} for a bundled diarization ONNX model with no download involved
- returns {:ok, path} for a whisper model once its download is checksum-verified
- the path returned in {:ok, path} points to a file that exists on disk

### download_model/1

Starts a verified, resumable download of a model in the background.

```elixir
@spec download_model(String.t()) :: {:ok, reference()} | {:error, :unknown_model | :already_downloaded}
```

**Process**:
1. Looks up `model_id` in the catalog; returns `{:error, :unknown_model}` when unrecognized.
2. Returns `{:error, :already_downloaded}` when the model is already downloaded and checksum-verified.
3. Delegates to EarWitness.Models.Downloader to fetch the file (resuming a partial file left by a prior interrupted attempt), verify it against the catalog's checksum, and report progress as it runs.
4. Returns immediately with a reference identifying this download; the transfer itself proceeds without blocking the caller, so unrelated app activity started afterward is unaffected while it runs.
5. Broadcasts progress and status changes as they happen.

**Test Assertions**:
- returns {:error, :unknown_model} for an id not in the catalog
- returns {:error, :already_downloaded} when the model is already verified on disk
- returns before the transfer has finished
- starting a live capture while this download is still running is neither refused nor queued behind it
- download_status/1 reflects :downloading shortly after this returns and eventually reaches :verified

### download_status/1

Returns the current status of a model's download.

```elixir
@spec download_status(String.t()) :: %{status: :not_started | :downloading | :verifying | :verified | :failed, percent: non_neg_integer() | nil, error: term() | nil}
```

**Process**:
1. Reads the Downloader's latest recorded status for `model_id`; the context module holds no separate in-flight state of its own.
2. Reports `:not_started` when no download has ever been attempted for `model_id`.
3. Reports `:verified` only once the transferred file's checksum has been confirmed against the catalog's known checksum — a fully-transferred but unverified file is reported as `:verifying`, never `:verified`.
4. Reports `:failed` with an error reason (e.g. a network interruption) when the transfer was interrupted before completing.

**Test Assertions**:
- reports :not_started for a model that has never been downloaded
- reports :downloading with an advancing percent while the transfer runs
- reports :verified only after the checksum matches
- reports :failed with a network-related error reason after a simulated network interruption

### retry_download/1

Retries a previously failed or interrupted download, resuming rather than restarting from zero.

```elixir
@spec retry_download(String.t()) :: {:ok, reference()} | {:error, :unknown_model | :already_downloaded}
```

**Process**:
1. Looks up `model_id`'s recorded download status; proceeds the same way download_model/1 does, but resumes the Downloader's partial transfer instead of starting over.
2. On success, `downloaded?/1` becomes true and `model_id` becomes eligible for set_active_model/1.
3. Clears the prior `:failed` status once the retried transfer verifies successfully.

**Test Assertions**:
- succeeds after a simulated network interruption and results in a checksum-verified file
- the model that ends up downloaded is the one that was actually verified, never a partial or corrupt file
- download_status/1 no longer reports :failed once the retry verifies

### subscribe/0

Subscribes the calling process to model catalog, download-progress, and active-model change notifications.

```elixir
@spec subscribe() :: :ok
```

**Process**:
1. Subscribes the caller to this context's PubSub topic, mirroring the subscribe/0 pattern already used elsewhere in the app (e.g. EarWitness.LocalSettings, EarWitness.Transcription.Server).

**Test Assertions**:
- a subscribed process receives a message when download_model/1's progress changes
- a subscribed process receives a message when set_active_model/1 succeeds

## Dependencies

- EarWitness.Models.Catalog
- EarWitness.Models.Downloader
- EarWitness.Repo
- Phoenix.PubSub

## Components

### EarWitness.Models.Catalog

Known models — id, display name, size, quality/language tradeoffs, checksum, and download URL. Flags whether each model's file ships bundled with the app (the diarization ONNX models, and any bundled whisper tier) or must be fetched by the Downloader, and which model id is the catalog's recommended default (the preselected `large-v3-turbo`).

### EarWitness.Models.Downloader

Fetches a catalog model's file over HTTP (a hand-written Req client per the req_cassette ADR), verifies it against the catalog's checksum before the file is considered usable, resumes a partial transfer when retried after an interruption, and reports progress as it runs. Never lets a partially-downloaded or checksum-failed file be treated as complete.
