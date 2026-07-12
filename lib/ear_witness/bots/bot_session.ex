defmodule EarWitness.Bots.BotSession do
  @moduledoc """
  A dispatched bot — target meeting URL, the fixed identifying display
  name it presents in the meeting, optional schedule, lifecycle status,
  failure reason, and a reference to the resulting recording once
  complete.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias EarWitness.Recordings.Recording

  @type t :: %__MODULE__{}

  schema "bot_sessions" do
    field(:meeting_url, :string)
    field(:display_name, :string, default: "EarWitness Notetaker")

    field(:status, Ecto.Enum,
      values: [:dispatched, :recording, :completed, :recalled, :failed],
      default: :dispatched
    )

    field(:scheduled_at, :utc_datetime)
    field(:failure_reason, :string)

    belongs_to(:recording, Recording)

    timestamps()
  end

  @doc "Changeset for creating a bot session or transitioning its lifecycle status."
  def changeset(session, attrs) do
    session
    |> cast(attrs, [
      :meeting_url,
      :display_name,
      :status,
      :scheduled_at,
      :failure_reason,
      :recording_id
    ])
    |> validate_required([:meeting_url, :display_name, :status])
    |> foreign_key_constraint(:recording_id)
  end
end
