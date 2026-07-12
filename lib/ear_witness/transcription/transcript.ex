defmodule EarWitness.Transcription.Transcript do
  @moduledoc """
  Transcript of a recording — status, engine metadata, and its ordered
  segments.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias EarWitness.Recordings.Recording
  alias EarWitness.Transcription.Segment

  schema "transcripts" do
    field(:status, Ecto.Enum,
      values: [:queued, :transcribing, :completed, :failed],
      default: :queued
    )

    field(:engine, :string)
    field(:diarized_at, :utc_datetime)

    belongs_to(:recording, Recording)
    has_many(:segments, Segment)

    timestamps()
  end

  def changeset(transcript, attrs) do
    transcript
    |> cast(attrs, [:recording_id, :status, :engine, :diarized_at])
    |> validate_required([:recording_id, :status])
    |> foreign_key_constraint(:recording_id)
    |> unique_constraint(:recording_id)
  end
end
