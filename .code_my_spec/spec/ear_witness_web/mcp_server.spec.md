# EarWitnessWeb.McpServer

Local MCP tool surface for AI assistants — search the library, read transcripts and speaker data, and fetch recording metadata. What leaves the machine is only what the user's own assistant explicitly reads.

Runs Anubis (`anubis_mcp`) over its **stdio transport** (see the anubis-mcp ADR): an MCP client (Claude Code, Claude Desktop, etc.) launches/attaches to this as a local subprocess exchanging JSON-RPC over stdin/stdout. No network port is ever opened for assistant access. Scope is deliberately narrow — the three tools below are the entire surface: search and read (with speaker/timestamp attribution on every passage) plus a single write tool that attaches a summary/note to a recording. There is no transcript-edit or speaker-rename tool. Access is off by default, user-enabled in Settings, and instantly revocable — every tool call checks access first and returns `{:error, :access_revoked}` uniformly when it is off.

## Type

module

## Functions

### list_tools/0

Returns the MCP `tools/list` response: the fixed set of tools this server exposes, so a connecting client knows what it can call.

```elixir
@spec list_tools() :: {:ok, [%{name: String.t(), description: String.t()}]} | {:error, :access_revoked}
```

**Process**:
1. Check whether assistant access is currently enabled (the Settings-controlled toggle this module reads, e.g. via `Application.get_env(:ear_witness, __MODULE__)`).
2. If access is off, return `{:error, :access_revoked}` without describing any tool.
3. Otherwise return the fixed, sanctioned tool list: `search_transcripts`, `read_transcript`, `attach_summary` — never a transcript-edit or speaker-rename tool, because none is implemented anywhere in this module.

**Test Assertions**:
- returns `{:ok, tools}` where `tools` is a non-empty list whose names include `"search_transcripts"`, `"read_transcript"`, and `"attach_summary"`
- the returned tool names are exactly that sanctioned set — `MapSet.new(["search_transcripts", "read_transcript", "attach_summary"])` — with none containing `"edit"`, `"rename"`, or `"delete"`
- returns `{:error, :access_revoked}` once assistant access has been revoked

### search_transcripts/1

Full-text search over the transcript library on the assistant's behalf, delegating the query to `EarWitness.Search`.

```elixir
@spec search_transcripts(%{required(String.t()) => String.t()}) ::
        {:ok, %{results: [%{recording_id: String.t(), text: String.t(), speaker: String.t() | nil, timestamp: non_neg_integer()}]}}
        | {:error, :access_revoked}
```

**Process**:
1. Check assistant access; return `{:error, :access_revoked}` if it is off.
2. Run the `"query"` argument through `EarWitness.Search`.
3. Map each hit to a result carrying its `recording_id`, matching `text`, `speaker`, and `timestamp` — the same attribution already surfaced in the transcript editor and search UI — never a placeholder.

**Test Assertions**:
- given `%{"query" => "Testing"}` against a transcribed recording, returns `{:ok, %{results: results}}` where at least one result's `recording_id` matches that recording and its `text` contains `"Testing"`
- every result carries both a `:speaker` key and a `:timestamp` key
- returns `{:error, :access_revoked}` once assistant access has been revoked

### read_transcript/1

Reads one recording's full transcript for the assistant, segment by segment, plus whatever summary is currently attached.

```elixir
@spec read_transcript(%{required(String.t()) => String.t()}) ::
        {:ok, %{segments: [%{text: String.t(), speaker: String.t() | nil, timestamp: non_neg_integer()}], summary: String.t() | nil}}
        | {:error, :access_revoked}
```

**Process**:
1. Check assistant access; return `{:error, :access_revoked}` if it is off.
2. Load the transcript for `"recording_id"` via `EarWitness.Transcription`, with its segments in playback order.
3. Load the recording's currently attached summary (if any) via `EarWitness.Recordings`.
4. Return every segment's text with its speaker and timestamp, alongside the summary.

**Test Assertions**:
- given `%{"recording_id" => id}` for a transcribed recording, returns `{:ok, %{segments: segments}}` where at least one segment's `text` contains `"Testing"`
- every segment carries both a `:speaker` key and a `:timestamp` key
- the `:summary` in the result reflects the most recently `attach_summary/1`-written summary for that recording
- returns `{:error, :access_revoked}` once assistant access has been revoked

### attach_summary/1

The one write tool this surface allows: lets an assistant save a summary or note onto a recording. No other write operation exists here.

```elixir
@spec attach_summary(%{required(String.t()) => String.t()}) ::
        {:ok, %{recording_id: String.t(), summary: String.t()}} | {:error, :access_revoked}
```

**Process**:
1. Check assistant access; return `{:error, :access_revoked}` if it is off.
2. Persist `"summary"` onto the recording identified by `"recording_id"` via `EarWitness.Recordings`.
3. Return the recording id and the summary that was just written.

**Test Assertions**:
- given `%{"recording_id" => id, "summary" => text}`, returns `{:ok, %{recording_id: id, summary: text}}`
- a subsequent `read_transcript/1` call for the same `recording_id` returns that same summary text, proving the write is durably persisted, not just echoed

## Dependencies

- EarWitness.Transcription
- EarWitness.Recordings
- EarWitness.Search
