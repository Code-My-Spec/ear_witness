defmodule EarWitness.Speakers do
  @moduledoc """
  Who said what. Attributes transcript segments to speakers, and lets a
  detected speaker be named or forgotten.

  Full diarization (VAD + speaker-embedding ONNX models via ortex,
  clustering voice signatures within and across recordings — see
  `.code_my_spec/architecture/decisions/speaker-diarization.md`) is not
  implemented yet: `diarize_transcript/1` collapses every segment of a
  transcript to a single detected speaker rather than fabricating
  multi-speaker attribution it cannot honestly produce. That single
  speaker can still be named, and the name propagates to every segment,
  same as it would with real diarization.
  """

  import Ecto.Query

  alias EarWitness.Repo
  alias EarWitness.Speakers.Speaker
  alias EarWitness.Transcription.{Segment, Transcript}

  @doc """
  Assigns every segment of a transcript to a detected speaker, unless the
  transcript has already been diarized. Safe to call every time the
  transcript editor mounts.
  """
  @spec diarize_transcript(Transcript.t()) :: :ok
  def diarize_transcript(%Transcript{segments: segments}) do
    segments
    |> Enum.reject(& &1.speaker_id)
    |> attach_default_speaker()
  end

  defp attach_default_speaker([]), do: :ok

  defp attach_default_speaker(unassigned_segments) do
    {:ok, speaker} = %Speaker{} |> Speaker.changeset(%{}) |> Repo.insert()

    unassigned_segments
    |> Enum.each(fn segment ->
      segment
      |> Segment.changeset(%{speaker_id: speaker.id})
      |> Repo.update!()
    end)
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
end
