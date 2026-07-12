defmodule EarWitness.Transcription.Segment do
  @moduledoc """
  A timestamped utterance — current text, the immutable machine-heard
  text, start/end offsets (milliseconds), speaker id, and edit history.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias EarWitness.Transcription.Transcript

  schema "segments" do
    field(:text, :string)
    field(:machine_text, :string)
    field(:start_offset, :integer)
    field(:end_offset, :integer)
    field(:speaker_id, :integer)
    field(:history, {:array, :string}, default: [])

    belongs_to(:transcript, Transcript)

    timestamps()
  end

  def changeset(segment, attrs) do
    segment
    |> cast(attrs, [
      :transcript_id,
      :text,
      :machine_text,
      :start_offset,
      :end_offset,
      :speaker_id,
      :history
    ])
    |> validate_required([:transcript_id, :text, :machine_text, :start_offset, :end_offset])
  end
end
