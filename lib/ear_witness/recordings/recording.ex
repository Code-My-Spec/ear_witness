defmodule EarWitness.Recordings.Recording do
  @moduledoc """
  A recording — title, source, file placement, duration, and lifecycle
  status. Belongs to zero or more collections.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias EarWitness.Recordings.Collection

  schema "recordings" do
    field(:title, :string)
    # :bot is a legacy source (the meeting-bot feature was removed); kept in
    # the enum so any pre-existing bot-sourced rows still load.
    field(:source, Ecto.Enum, values: [:captured, :imported, :bot])
    field(:capture_source, Ecto.Enum, values: [:microphone, :system_audio_tap])
    field(:file_path, :string)
    field(:duration, :float)
    field(:status, Ecto.Enum, values: [:active, :trashed], default: :active)
    field(:trashed_at, :utc_datetime)
    field(:date, :date)
    field(:participants, :string)
    field(:summary, :string)

    many_to_many(:collections, Collection,
      join_through: "recording_collections",
      on_replace: :delete
    )

    timestamps()
  end

  @doc "Changeset for creating a recording (import or capture/bot hand-off)."
  def changeset(recording, attrs) do
    recording
    |> cast(attrs, [
      :title,
      :source,
      :capture_source,
      :file_path,
      :duration,
      :status,
      :date,
      :participants
    ])
    |> validate_required([:title, :source, :file_path, :duration, :status])
  end

  @doc "Changeset restricted to the user-editable metadata fields."
  def metadata_changeset(recording, attrs) do
    cast(recording, attrs, [:title, :date, :participants])
  end

  @doc "Changeset restricted to the summary an assistant may attach via MCP."
  def summary_changeset(recording, attrs) do
    cast(recording, attrs, [:summary])
  end
end
