defmodule EarWitness.Models do
  @moduledoc """
  Managed AI model files — the whisper model catalog (size/quality/language
  tradeoffs) and selection of the active transcription model. Downloads
  run with progress and checksum verification, stored under
  `EarWitness.models_dir/0`; model setup is driven through
  `EarWitnessWeb.SetupLive` (and the settings page), never called
  directly from BDD specs (see the local Credo check `EARWIT0001`).
  """

  import Ecto.Query

  alias EarWitness.Models.{Catalog, Downloader, ModelSettings, VerifiedModel}
  alias EarWitness.Repo

  @topic "models"

  defdelegate list_models(), to: Catalog
  defdelegate get_model(model_id), to: Catalog
  defdelegate default_model_id(), to: Catalog

  @doc """
  The model currently selected for transcription. On a fresh install with
  nothing chosen, falls back to the bundled `base` model so the app can
  transcribe immediately (setup is optional, not forced — story 866, PM
  decision 2026-07-12).
  """
  @spec get_active_model() :: Catalog.model() | nil
  def get_active_model, do: Catalog.get_model(active_model_id())

  @doc "Makes `model_id` the app-wide active transcription model."
  @spec set_active_model(String.t()) ::
          {:ok, Catalog.model()} | {:error, :unknown_model | :not_downloaded}
  def set_active_model(model_id) do
    case Catalog.get_model(model_id) do
      nil -> {:error, :unknown_model}
      model -> activate(model)
    end
  end

  @doc "Whether a model's file is present and checksum-verified on disk."
  @spec downloaded?(String.t()) :: boolean()
  def downloaded?(model_id) do
    case Catalog.get_model(model_id) do
      nil -> false
      %{bundled: true} -> true
      _model -> verified_in_db?(model_id)
    end
  end

  @doc "Resolves a model id to the absolute file path used to load it."
  @spec model_path(String.t()) :: {:ok, Path.t()} | {:error, :not_downloaded}
  def model_path(model_id) do
    case Catalog.get_model(model_id) do
      %{bundled: true} = model -> {:ok, Catalog.bundled_path(model)}
      %{} = model -> downloaded_path_if_verified(model_id, model)
      nil -> {:error, :not_downloaded}
    end
  end

  @doc "Starts a verified, resumable, backgrounded download of a model."
  @spec download_model(String.t()) ::
          {:ok, reference()} | {:error, :unknown_model | :already_downloaded}
  def download_model(model_id) do
    case Catalog.get_model(model_id) do
      nil -> {:error, :unknown_model}
      model -> start_download(model_id, model)
    end
  end

  @doc "Retries a previously failed or interrupted download."
  @spec retry_download(String.t()) ::
          {:ok, reference()} | {:error, :unknown_model | :already_downloaded}
  def retry_download(model_id), do: download_model(model_id)

  @doc """
  Deletes a downloaded model's file and its verification record, freeing
  the disk. Bundled models can't be deleted (they ship inside the app). If
  the deleted model was the active one, the active model resets to the
  bundled model so the app can still transcribe.
  """
  @spec delete_model(String.t()) :: :ok | {:error, :unknown_model | :bundled}
  def delete_model(model_id) do
    case Catalog.get_model(model_id) do
      nil -> {:error, :unknown_model}
      %{bundled: true} -> {:error, :bundled}
      model -> remove_download(model_id, model)
    end
  end

  @doc "The current status of a model's download."
  @spec download_status(String.t()) :: Downloader.progress()
  def download_status(model_id) do
    case downloaded?(model_id) do
      true -> %{status: :verified, percent: 100, error: nil}
      false -> Downloader.status(model_id)
    end
  end

  @doc "Subscribes the caller to catalog, download-progress, and active-model change notifications."
  @spec subscribe() :: :ok
  def subscribe, do: Phoenix.PubSub.subscribe(EarWitness.PubSub, @topic)

  @doc """
  Blocks the calling process until `model_id`'s download reaches a
  terminal status (`:verified` or `:failed`), or `timeout` elapses —
  whichever comes first. `download_model/1` itself never blocks; this is
  a separate, optional convenience for callers (like `SetupLive`) that
  want to react to a fast download's outcome as part of the same event,
  without polling. The caller must already be subscribed (`subscribe/0`)
  for this to observe anything before `timeout`.
  """
  @spec await_download(String.t(), timeout()) :: Downloader.progress()
  def await_download(model_id, timeout \\ 5_000) do
    status = download_status(model_id)

    case terminal?(status) do
      true -> status
      false -> await_terminal_message(model_id, System.monotonic_time(:millisecond) + timeout)
    end
  end

  # Private helpers

  defp activate(%{id: model_id} = model) do
    case downloaded?(model_id) do
      false ->
        {:error, :not_downloaded}

      true ->
        settings()
        |> ModelSettings.changeset(%{active_model_id: model_id})
        |> Repo.update!()

        broadcast({:active_model_changed, model})
        {:ok, model}
    end
  end

  defp remove_download(model_id, model) do
    _ = File.rm(downloaded_path(model))
    Repo.delete_all(from(v in VerifiedModel, where: v.model_id == ^model_id))

    if active_model_id() == model_id do
      settings()
      |> ModelSettings.changeset(%{active_model_id: Catalog.bundled_model_id()})
      |> Repo.update!()
    end

    broadcast({:model_deleted, model})
    :ok
  end

  defp start_download(model_id, model) do
    case downloaded?(model_id) do
      true ->
        {:error, :already_downloaded}

      false ->
        Downloader.start(model_id, model.download_url, expected_checksum(model), downloaded_path(model))
    end
  end

  # Production verifies against the catalog's real hosted-file SHA-256.
  # Tests replay a small stub body via ReqCassette, so config/test.exs maps
  # the model id to the stub's hash here — keeping the catalog honest about
  # the real file while the fixture still verifies (story 866).
  defp expected_checksum(%{id: id, checksum: checksum}) do
    :ear_witness
    |> Application.get_env(:model_checksum_overrides, %{})
    |> Map.get(id, checksum)
  end

  defp downloaded_path_if_verified(model_id, model) do
    case downloaded?(model_id) do
      true -> {:ok, downloaded_path(model)}
      false -> {:error, :not_downloaded}
    end
  end

  defp verified_in_db?(model_id) do
    Repo.exists?(from(v in VerifiedModel, where: v.model_id == ^model_id))
  end

  defp terminal?(%{status: status}), do: status in [:verified, :failed]

  defp await_terminal_message(model_id, deadline) do
    receive do
      {:model_download_progress, ^model_id, progress} ->
        case terminal?(progress) do
          true -> record_if_verified(model_id, progress)
          false -> await_terminal_message(model_id, deadline)
        end
    after
      max(deadline - System.monotonic_time(:millisecond), 0) -> download_status(model_id)
    end
  end

  # Persists verification synchronously, in the same process that observed
  # it, rather than via a separate subscriber process racing this one for
  # the shared sandbox connection in tests (that raced design intermittently
  # hit "Database busy" under full-suite load — see git history).
  defp record_if_verified(model_id, %{status: :verified} = progress) do
    %VerifiedModel{}
    |> VerifiedModel.changeset(%{model_id: model_id})
    |> Repo.insert(on_conflict: :nothing, conflict_target: :model_id)

    progress
  end

  defp record_if_verified(_model_id, progress), do: progress

  defp downloaded_path(%{id: model_id}),
    do: Path.join(EarWitness.models_dir(), model_id <> ".bin")

  # Falls back to the bundled model when nothing has been explicitly
  # activated, so a fresh install is never left with no usable model.
  # Read-only (see read_settings/0): reading the active model must never
  # write — get_active_model is called on many page mounts.
  defp active_model_id, do: read_settings().active_model_id || Catalog.bundled_model_id()

  # Read-only accessor: NEVER writes. Returns the singleton row or an
  # unpersisted %ModelSettings{} (active_model_id nil, so callers fall back).
  # Avoids the write-on-read INSERT that raced other writes on a fresh DB.
  defp read_settings do
    case Repo.all(from(s in ModelSettings, order_by: s.id, limit: 1)) do
      [settings | _] -> settings
      [] -> %ModelSettings{}
    end
  end

  # Get-or-create for WRITES only (activate/2 needs a persisted row).
  # Two concurrent first-requests can both see an empty table and both insert
  # (TOCTOU) — so tolerate duplicates: always use the lowest-id row and prune
  # any extras rather than crashing on `[a, b]`.
  defp settings do
    case Repo.all(from(s in ModelSettings, order_by: s.id)) do
      [] -> insert_singleton()
      [settings] -> settings
      [settings | _extras] -> settings
    end
  end

  # A unique index guards against a second row (migration
  # dedupe_and_guard_singletons); if a concurrent request wins the insert
  # race, `on_conflict: :nothing` makes our insert a no-op and we re-read
  # the winner rather than raising.
  defp insert_singleton do
    %ModelSettings{}
    |> ModelSettings.changeset(%{})
    |> Repo.insert!(on_conflict: :nothing)

    Repo.one!(from(s in ModelSettings, order_by: s.id, limit: 1))
  end

  defp broadcast(message), do: Phoenix.PubSub.broadcast(EarWitness.PubSub, @topic, message)
end
