defmodule EarWitness.Audio do
  @moduledoc """
  Live audio capture infrastructure — capture-source and consent-policy
  selection, and starting/stopping capture sessions. Has no knowledge of
  recordings, files, or the library; `EarWitness.Recordings` composes this
  context for live capture. Never joins a meeting and never depends on
  `EarWitness.Bots` — capture reads local audio devices only.
  """

  import Ecto.Query
  alias EarWitness.Audio.{ConsentPolicy, Miniaudio, Pipeline, Settings, Tap}
  alias EarWitness.Repo

  @doc false
  # Legacy: still used by EarWitnessWeb.TodoLive's device pickers.
  def list_devices, do: Miniaudio.list_devices()

  @doc "Lists the capture sources available on this machine."
  @spec list_capture_sources() ::
          [
            %{
              type: :microphone | :system_audio_tap,
              id: term(),
              name: String.t(),
              available: boolean()
            }
          ]
  def list_capture_sources do
    [
      %{
        type: :microphone,
        id: :microphone,
        name: "Microphone",
        available: Pipeline.input_devices() != []
      },
      %{
        type: :system_audio_tap,
        id: :system_audio_tap,
        name: "System Audio Tap",
        available: Tap.installed?()
      }
    ]
  end

  @doc "Returns the capture source the next call to `start_capture/1` will use."
  @spec get_active_capture_source() :: :microphone | :system_audio_tap
  def get_active_capture_source, do: read_settings().active_capture_source

  @doc "Persists the capture source that future captures will use."
  @spec set_active_capture_source(:microphone | :system_audio_tap) ::
          {:ok, :microphone | :system_audio_tap} | {:error, :source_unavailable}
  def set_active_capture_source(source) do
    if Enum.any?(list_capture_sources(), &(&1.type == source and &1.available)) do
      {:ok, updated} =
        settings()
        |> Settings.changeset(%{active_capture_source: source})
        |> Repo.update()

      {:ok, updated.active_capture_source}
    else
      {:error, :source_unavailable}
    end
  end

  @doc "Returns the recording consent/notification policy currently governing capture."
  @spec get_consent_policy() :: :silent | :notify | :announce
  def get_consent_policy, do: read_settings().consent_policy

  @doc "Persists the recording consent/notification policy that will govern future captures."
  @spec set_consent_policy(:silent | :notify | :announce) :: {:ok, :silent | :notify | :announce}
  def set_consent_policy(policy) do
    {:ok, updated} =
      settings()
      |> Settings.changeset(%{consent_policy: policy})
      |> Repo.update()

    {:ok, updated.consent_policy}
  end

  @doc "Lists the three selectable consent policies with an explanation, plus a shared disclaimer."
  @spec list_consent_policies() :: {[%{id: atom(), explanation: String.t()}], String.t()}
  def list_consent_policies do
    {
      [
        %{
          id: :silent,
          explanation: "Records with no notice shown. Use only where you already have consent."
        },
        %{id: :notify, explanation: "Shows an on-screen notice that recording is active."},
        %{
          id: :announce,
          explanation:
            "Plays an audible notice and waits for it to be delivered before recording."
        }
      ],
      "This is general guidance, not legal advice — recording-consent laws vary by jurisdiction."
    }
  end

  @doc """
  Starts live capture on the active capture source under the active
  consent policy, writing to `path`.
  """
  @spec start_capture(Path.t()) ::
          {:ok,
           %{
             ref: reference(),
             channels: [:microphone | :system_audio],
             notice: :none | :shown | :delivered
           }}
          | {:error, :no_input_device | :notice_undelivered | :source_unavailable}
  def start_capture(path) do
    with {:ok, notice} <- ConsentPolicy.authorize(get_consent_policy()),
         {:ok, ref, channels} <- Pipeline.capture(get_active_capture_source(), path) do
      {:ok, %{ref: ref, channels: channels, notice: notice}}
    end
  end

  @doc "Stops a running capture and finalizes the file on disk."
  @spec stop_capture(reference()) ::
          {:ok, %{ref: reference(), channels: [:microphone | :system_audio], path: Path.t()}}
  def stop_capture(ref) do
    with {:ok, %{channels: channels, path: path}} <- Pipeline.stop(ref) do
      {:ok, %{ref: ref, channels: channels, path: path}}
    end
  end

  @doc "Subscribes the caller to live input-level updates for a running capture."
  @spec subscribe_levels(reference()) :: :ok
  def subscribe_levels(ref) do
    Phoenix.PubSub.subscribe(EarWitness.PubSub, levels_topic(ref))
  end

  defp levels_topic(ref), do: "audio_levels:#{inspect(ref)}"

  # Read-only accessor: NEVER writes. Returns the singleton row, or an
  # unpersisted %Settings{} carrying the schema defaults (:microphone /
  # :notify) when the row doesn't exist yet. Readers (get_active_capture_source,
  # get_consent_policy) use this so a page mount / consent check never triggers
  # an INSERT — write-on-read was a real lock-contention source (a fresh test
  # DB inserts the singleton on first access, racing the run's other writes).
  defp read_settings do
    case Repo.all(from(s in Settings, order_by: s.id, limit: 1)) do
      [settings | _] -> settings
      [] -> %Settings{}
    end
  end

  # Get-or-create for WRITES only (set_* needs a persisted row to update).
  # Tolerates the concurrent-insert race by always using the lowest-id row and
  # pruning duplicates (see EarWitness.Models.settings/0).
  defp settings do
    case Repo.all(from(s in Settings, order_by: s.id)) do
      [] ->
        # Unique-index-guarded singleton (see EarWitness.Models.settings/0);
        # a race-lost insert no-ops and we re-read the winner.
        %Settings{} |> Settings.changeset(%{}) |> Repo.insert!(on_conflict: :nothing)
        Repo.one!(from(s in Settings, order_by: s.id, limit: 1))

      [settings | _] ->
        settings
    end
  end
end
