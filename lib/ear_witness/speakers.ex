defmodule EarWitness.Speakers do
  @moduledoc """
  Who said what. Diarizes transcripts via the `EarWitness.Speakers.Diarizer`
  seam (VAD-free segmentation, spectral clustering, and WeSpeaker voice
  embeddings, all on-device — see
  `.code_my_spec/architecture/decisions/speaker-diarization.md`), and
  lets a detected speaker be named or forgotten.

  Depends on `EarWitness.Recordings` (to look up a transcript's
  recording and hand its audio file to the diarizer) in addition to
  `EarWitness.Models` and `EarWitness.Transcription` — see
  `.code_my_spec/spec/ear_witness/speakers.spec.md`.

  Cross-recording recognition: before a newly detected speaker becomes a
  new `Speaker` row, its voice-embedding centroid is matched (cosine
  similarity) against every existing speaker's stored embedding — a
  strong match reuses that speaker's id instead, so a recurring voice
  keeps resolving to the same named person across recordings.
  `forget_speaker/1` deletes the row (embedding included), so nothing
  about that voice can match again.

  Overlapping or unclear speech doesn't get guessed into either
  candidate speaker: `diarize_transcript/1` leaves those segments
  unattributed (`speaker_id: nil`), which `label/2` renders as
  "Unknown".
  """

  import Ecto.Query

  alias EarWitness.Recordings
  alias EarWitness.Repo
  alias EarWitness.Speakers.Speaker
  alias EarWitness.Transcription.{Segment, Transcript}

  # Cosine similarity above which two embeddings are considered the same
  # voice. `EarWitness.Speakers.Diarizer.Fbank` isn't bit-exact with the
  # Kaldi feature extraction the embedding model trained against (see
  # its moduledoc), so this is calibrated from real measurements against
  # `test/fixtures/diarize.raw` (same speaker, independent turns:
  # 0.44-0.67 cosine similarity; different speakers: 0.15-0.39) rather
  # than a value borrowed from the model's own paper — expect to retune
  # this against a broader set of real recordings.
  @match_threshold 0.5

  @doc """
  Assigns every segment of a transcript to a detected speaker (or to no
  speaker, for overlapping/unclear speech), unless the transcript has
  already been diarized. Safe to call every time the transcript editor
  mounts.

  A transcript that isn't `:completed` is skipped without being marked:
  during live capture only transcription runs in real time — segmentation
  and clustering wait for the recording to finish. Diarizing mid-capture
  would burn heavy ONNX compute alongside the live whisper loop, and since
  the capture WAV is empty until stop, the diarizer's error path would
  stamp `diarized_at` and silently disable the real post-stop pass.
  """
  @spec diarize_transcript(Transcript.t()) :: :ok
  def diarize_transcript(%Transcript{diarized_at: diarized_at}) when not is_nil(diarized_at) do
    :ok
  end

  def diarize_transcript(%Transcript{status: status}) when status != :completed do
    :ok
  end

  def diarize_transcript(%Transcript{} = transcript) do
    {:ok, recording} = Recordings.get_recording(transcript.recording_id)
    diarizer = Application.get_env(:ear_witness, :diarizer, EarWitness.Speakers.Diarizer.Onnx)

    case diarizer.diarize(recording) do
      {:ok, turns} -> apply_diarization(transcript, turns)
      {:error, _reason} -> mark_diarized(transcript)
    end

    :ok
  end

  @doc "Lists the speakers detected on a transcript, in a stable display order."
  @spec list_speakers_for_transcript(Transcript.t()) :: [Speaker.t()]
  def list_speakers_for_transcript(%Transcript{segments: segments}) do
    speaker_ids =
      segments
      |> Enum.map(& &1.speaker_id)
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()

    Repo.all(from(s in Speaker, where: s.id in ^speaker_ids, order_by: s.id))
  end

  @doc """
  Distinct chosen speaker names across the whole library, sorted — the set
  worth offering as a global filter (e.g. the /search speaker dropdown).
  Only named speakers are returned; generic "Speaker N" labels are
  per-transcript indices and not globally meaningful to filter on.
  """
  @spec list_speaker_names() :: [String.t()]
  def list_speaker_names do
    Repo.all(
      from(s in Speaker,
        where: not is_nil(s.name),
        order_by: s.name,
        select: s.name,
        distinct: true
      )
    )
  end

  @doc """
  The display label for a speaker: their chosen name, a generic
  "Speaker N" (1-indexed by `index`) before naming, or "Unknown" when no
  speaker was detected at all.
  """
  @spec label(Speaker.t() | nil, non_neg_integer()) :: String.t()
  def label(nil, _index), do: "Unknown"
  def label(%Speaker{name: name}, _index) when is_binary(name), do: name
  def label(%Speaker{name: nil}, index), do: "Speaker #{index + 1}"

  @doc "Renames a detected speaker; the new name is shown on every segment attributed to them."
  @spec rename_speaker(integer() | binary(), String.t()) ::
          {:ok, Speaker.t()} | {:error, Ecto.Changeset.t()}
  def rename_speaker(speaker_id, name) do
    Speaker
    |> Repo.get!(speaker_id)
    |> Speaker.changeset(%{name: name})
    |> Repo.update()
  end

  @doc """
  Finds a speaker by exact name, or creates a new named speaker — the editor's
  type-to-create path for attributing a segment to a person by name. The new
  speaker carries no voice embedding (it wasn't detected from audio), so it
  won't auto-match future recordings until it accrues one.
  """
  @spec find_or_create_by_name(String.t()) :: Speaker.t()
  def find_or_create_by_name(name) do
    case Repo.one(from(s in Speaker, where: s.name == ^name)) do
      nil ->
        {:ok, speaker} = %Speaker{} |> Speaker.changeset(%{name: name}) |> Repo.insert()
        speaker

      speaker ->
        speaker
    end
  end

  @doc """
  Forgets a speaker's voice signature. Segments already attributed to
  them keep their `speaker_id`, but since the speaker row is gone they
  display as "Unknown" going forward, and nothing about them can match
  future recordings.
  """
  @spec forget_speaker(integer() | binary()) :: :ok
  def forget_speaker(speaker_id) do
    Speaker
    |> Repo.get!(speaker_id)
    |> Repo.delete!()

    :ok
  end

  # -- diarization -------------------------------------------------------

  defp apply_diarization(transcript, turns) do
    speaker_ids_by_cluster = resolve_clusters(turns)

    Enum.each(transcript.segments, fn segment ->
      speaker_id = best_speaker_id(segment, turns, speaker_ids_by_cluster)

      segment
      |> Segment.changeset(%{speaker_id: speaker_id})
      |> Repo.update!()
    end)

    mark_diarized(transcript)
  end

  # One resolved (matched-or-created) Speaker id per non-`nil` cluster —
  # so every turn belonging to the same detected voice within this call
  # maps to the same Speaker row, created once.
  defp resolve_clusters(turns) do
    turns
    |> Enum.reject(&is_nil(&1.cluster))
    |> Enum.group_by(& &1.cluster)
    |> Map.new(fn {cluster, cluster_turns} -> {cluster, resolve_speaker_id(cluster_turns)} end)
  end

  defp resolve_speaker_id(cluster_turns) do
    embedding =
      cluster_turns
      |> Enum.map(& &1.embedding)
      |> Enum.reject(&is_nil/1)
      |> centroid()

    case embedding && find_matching_speaker(embedding) do
      %Speaker{id: id} -> id
      _ -> create_speaker(embedding).id
    end
  end

  defp find_matching_speaker(embedding) do
    Speaker
    |> Repo.all()
    |> Enum.reject(&is_nil(&1.embedding))
    |> Enum.map(&{&1, cosine_similarity(&1.embedding, embedding)})
    |> Enum.filter(fn {_speaker, similarity} -> similarity >= @match_threshold end)
    |> Enum.max_by(fn {_speaker, similarity} -> similarity end, fn -> {nil, 0.0} end)
    |> elem(0)
  end

  defp create_speaker(embedding) do
    {:ok, speaker} = %Speaker{} |> Speaker.changeset(%{embedding: embedding}) |> Repo.insert()
    speaker
  end

  # The cluster whose turns overlap `segment` the most (by total
  # millisecond overlap) wins its attribution; a segment with no
  # overlapping turn, or whose best-overlapping turn is an ambiguous one
  # (`cluster: nil`), is left unattributed ("Unknown").
  defp best_speaker_id(segment, turns, speaker_ids_by_cluster) do
    turns
    |> Enum.map(&{&1.cluster, overlap_ms(segment, &1)})
    |> Enum.filter(fn {_cluster, overlap} -> overlap > 0 end)
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
    |> Enum.map(fn {cluster, overlaps} -> {cluster, Enum.sum(overlaps)} end)
    |> Enum.max_by(&elem(&1, 1), fn -> {nil, 0} end)
    |> elem(0)
    |> then(&Map.get(speaker_ids_by_cluster, &1))
  end

  defp overlap_ms(%Segment{start_offset: s, end_offset: e}, %{start_ms: ts, end_ms: te}) do
    max(0, min(e, te) - max(s, ts))
  end

  defp mark_diarized(transcript) do
    transcript
    |> Transcript.changeset(%{diarized_at: DateTime.utc_now() |> DateTime.truncate(:second)})
    |> Repo.update!()
  end

  defp centroid([]), do: nil

  defp centroid(embeddings) do
    dimensions = embeddings |> hd() |> length()
    zero = List.duplicate(0.0, dimensions)

    embeddings
    |> Enum.reduce(zero, fn embedding, acc -> Enum.zip_with(embedding, acc, &+/2) end)
    |> Enum.map(&(&1 / length(embeddings)))
  end

  defp cosine_similarity(a, b) do
    dot = Enum.zip_with(a, b, &*/2) |> Enum.sum()
    norm_a = a |> Enum.map(&(&1 * &1)) |> Enum.sum() |> :math.sqrt()
    norm_b = b |> Enum.map(&(&1 * &1)) |> Enum.sum() |> :math.sqrt()

    if norm_a == 0.0 or norm_b == 0.0, do: 0.0, else: dot / (norm_a * norm_b)
  end
end
