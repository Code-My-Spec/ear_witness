defmodule EarWitnessWeb.McpServer do
  @moduledoc """
  Local MCP tool surface for AI assistants — search the library, read
  transcripts and speaker data, and fetch recording metadata. What leaves
  the machine is only what the user's own assistant explicitly reads.

  Runs over Anubis's **stdio transport** (see the anubis-mcp ADR): an MCP
  client (Claude Code, Claude Desktop, etc.) launches/attaches to this as a
  local subprocess exchanging JSON-RPC over stdin/stdout. No network port
  is ever opened for assistant access — `EarWitnessWeb.McpServer.Server`
  registers the tool components below (`EarWitnessWeb.McpServer.Tools.*`,
  each a thin `Anubis.Server.Component` wrapper) and is started with
  `transport: :stdio`, never `:streamable_http`.

  Scope is deliberately narrow — `search_transcripts/1`,
  `read_transcript/1`, and `attach_summary/1` (plus `list_tools/0` to
  enumerate them) are the entire surface. There is no transcript-edit or
  speaker-rename tool. Access is off by default, user-enabled in Settings
  (`EarWitnessWeb.SettingsLive`'s `assistant-access-form`), and instantly
  revocable — every function here checks `EarWitness.Assistant.get_access/0`
  first and returns `{:error, :access_revoked}` uniformly when it is off.

  This module is the sanctioned direct-call surface for BDD specs (see
  `.code_my_spec/knowledge/bdd/spex/index.md`, story 868): a spec calls
  these functions exactly the way an MCP client's tool call would, and
  asserts on the result tuples, rather than opening a stdio connection.
  """

  alias EarWitness.Assistant
  alias EarWitness.Recordings
  alias EarWitness.Search
  alias EarWitness.Speakers
  alias EarWitness.Transcription

  @tools [
    %{name: "search_transcripts", description: "Full-text search over the transcript library."},
    %{
      name: "read_transcript",
      description: "Read one recording's full transcript, segment by segment, plus its summary."
    },
    %{name: "attach_summary", description: "Attach a summary/note to a recording."}
  ]

  @doc """
  Returns the MCP `tools/list` response: the fixed set of tools this
  server exposes, so a connecting client knows what it can call.
  """
  @spec list_tools() ::
          {:ok, [%{name: String.t(), description: String.t()}]} | {:error, :access_revoked}
  def list_tools do
    with_access(fn -> {:ok, @tools} end)
  end

  @doc """
  Full-text search over the transcript library on the assistant's behalf,
  delegating the query to `EarWitness.Search`.
  """
  @spec search_transcripts(%{required(String.t()) => String.t()}) ::
          {:ok,
           %{
             results: [
               %{
                 recording_id: String.t(),
                 text: String.t(),
                 speaker: String.t() | nil,
                 timestamp: non_neg_integer()
               }
             ]
           }}
          | {:error, :access_revoked}
  def search_transcripts(%{"query" => query}) do
    with_access(fn ->
      results =
        query
        |> Search.search()
        |> Enum.filter(&(&1.type == :segment))
        |> Enum.map(fn hit ->
          %{
            recording_id: to_string(hit.recording_id),
            text: hit.snippet,
            speaker: hit.speaker,
            timestamp: hit.timestamp
          }
        end)

      {:ok, %{results: results}}
    end)
  end

  @doc """
  Reads one recording's full transcript for the assistant, segment by
  segment, plus whatever summary is currently attached.
  """
  @spec read_transcript(%{required(String.t()) => String.t()}) ::
          {:ok,
           %{
             segments: [
               %{text: String.t(), speaker: String.t() | nil, timestamp: non_neg_integer()}
             ],
             summary: String.t() | nil
           }}
          | {:error, :access_revoked}
  def read_transcript(%{"recording_id" => recording_id}) do
    with_access(fn ->
      with {:ok, recording} <- Recordings.get_recording(recording_id),
           {:ok, transcript} <- Transcription.get_transcript_for_recording(recording.id) do
        {:ok, %{segments: build_segments(transcript), summary: recording.summary}}
      end
    end)
  end

  @doc """
  The one write tool this surface allows: lets an assistant save a
  summary or note onto a recording. No other write operation exists here.
  """
  @spec attach_summary(%{required(String.t()) => String.t()}) ::
          {:ok, %{recording_id: String.t(), summary: String.t()}} | {:error, :access_revoked}
  def attach_summary(%{"recording_id" => recording_id, "summary" => summary}) do
    with_access(fn ->
      with {:ok, recording} <- Recordings.get_recording(recording_id),
           {:ok, updated} <- Recordings.attach_summary(recording, summary) do
        {:ok, %{recording_id: to_string(updated.id), summary: updated.summary}}
      end
    end)
  end

  defp build_segments(transcript) do
    speakers = Speakers.list_speakers_for_transcript(transcript)

    Enum.map(transcript.segments, fn segment ->
      %{
        text: segment.text,
        speaker: speaker_label(segment.speaker_id, speakers),
        timestamp: segment.start_offset
      }
    end)
  end

  defp with_access(fun) do
    case Assistant.get_access() do
      :enabled -> fun.()
      :disabled -> {:error, :access_revoked}
    end
  end

  defp speaker_label(nil, _speakers), do: nil

  defp speaker_label(speaker_id, speakers) do
    index = Enum.find_index(speakers, &(&1.id == speaker_id)) || 0
    speaker = Enum.find(speakers, &(&1.id == speaker_id))
    Speakers.label(speaker, index)
  end
end
