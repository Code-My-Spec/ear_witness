defmodule EarWitness.Recordings do
  @moduledoc """
  The recordings library — every piece of audio the app knows about,
  whether captured live from the microphone or imported from an external
  file. Owns recording metadata,
  collection ("case/matter/meeting") grouping, and file placement.
  """

  import Ecto.Query

  alias EarWitness.Audio
  alias EarWitness.Recordings.{Collection, Importer, Recording, WavHeader}
  alias EarWitness.Repo
  alias EarWitness.Search

  @doc "Validates, copies, and registers an externally-sourced audio file as a new recording."
  @spec import_recording(Path.t(), String.t()) ::
          {:ok, Recording.t()} | {:error, :invalid_audio_file | Ecto.Changeset.t()}
  def import_recording(upload_path, filename) do
    with {:ok, %{file_path: file_path, duration: duration}} <-
           Importer.import(upload_path, filename) do
      %Recording{}
      |> Recording.changeset(%{
        title: filename,
        source: :imported,
        file_path: file_path,
        duration: duration,
        status: :active
      })
      |> Repo.insert()
      |> index_for_search()
    end
  end

  @doc "Registers an already-captured, already-normalized audio file as a new recording."
  @spec create_recording(map()) :: {:ok, Recording.t()} | {:error, Ecto.Changeset.t()}
  def create_recording(attrs) do
    %Recording{}
    |> Recording.changeset(Map.put_new(attrs, :status, :active))
    |> Repo.insert()
    |> index_for_search()
  end

  @doc "Fetches a single recording by id, preloaded with its collection memberships."
  @spec get_recording(term()) :: {:ok, Recording.t()} | {:error, :not_found}
  def get_recording(id) when is_integer(id) do
    case Repo.get(Recording, id) do
      nil -> {:error, :not_found}
      recording -> {:ok, Repo.preload(recording, :collections)}
    end
  end

  def get_recording(id) when is_binary(id) do
    case Integer.parse(id) do
      {int, ""} -> get_recording(int)
      _ -> {:error, :not_found}
    end
  end

  def get_recording(_id), do: {:error, :not_found}

  @doc "Lists every active (non-trashed) recording, most recently created first."
  @spec list_recordings() :: [Recording.t()]
  def list_recordings do
    Recording
    |> where([r], r.status == :active)
    |> order_by([r], desc: r.inserted_at, desc: r.id)
    |> Repo.all()
  end

  @doc "Lists every collection, each preloaded with its active member recordings."
  @spec list_collections() :: [Collection.t()]
  def list_collections do
    active_recordings = from(r in Recording, where: r.status == :active)

    Collection
    |> Repo.all()
    |> Repo.preload(recordings: active_recordings)
  end

  @doc "Lists active recordings that belong to no collection."
  @spec list_uncategorized_recordings() :: [Recording.t()]
  def list_uncategorized_recordings do
    from(r in Recording,
      left_join: rc in "recording_collections",
      on: rc.recording_id == r.id,
      where: r.status == :active and is_nil(rc.collection_id),
      order_by: [desc: r.inserted_at, desc: r.id],
      select: r
    )
    |> Repo.all()
  end

  @doc "Updates a recording's editable metadata — title, date, and participants."
  @spec update_recording(Recording.t(), map()) ::
          {:ok, Recording.t()} | {:error, Ecto.Changeset.t()}
  def update_recording(%Recording{} = recording, attrs) do
    recording
    |> Recording.metadata_changeset(attrs)
    |> Repo.update()
    |> index_for_search()
  end

  @doc """
  Attaches (or replaces) a summary/note on a recording — the one write an
  AI assistant may perform via `EarWitnessWeb.McpServer.attach_summary/1`.
  """
  @spec attach_summary(Recording.t(), String.t()) ::
          {:ok, Recording.t()} | {:error, Ecto.Changeset.t()}
  def attach_summary(%Recording{} = recording, summary) do
    recording
    |> Recording.summary_changeset(%{summary: summary})
    |> Repo.update()
  end

  @doc "Replaces a recording's full collection membership with exactly the given set."
  @spec set_recording_collections(Recording.t(), [term()]) ::
          {:ok, Recording.t()} | {:error, Ecto.Changeset.t()}
  def set_recording_collections(%Recording{} = recording, collection_ids) do
    collections = Repo.all(from(c in Collection, where: c.id in ^collection_ids))

    recording
    |> Repo.preload(:collections)
    |> Ecto.Changeset.change()
    |> Ecto.Changeset.put_assoc(:collections, collections)
    |> Repo.update()
    |> index_for_search()
  end

  @doc "Creates a new collection ('case/matter/meeting')."
  @spec create_collection(map()) :: {:ok, Collection.t()} | {:error, Ecto.Changeset.t()}
  def create_collection(attrs) do
    %Collection{}
    |> Collection.changeset(attrs)
    |> Repo.insert()
  end

  @doc "Deletes a collection without cascading to its member recordings."
  @spec delete_collection(Collection.t()) :: {:ok, Collection.t()} | {:error, Ecto.Changeset.t()}
  def delete_collection(%Collection{id: id} = collection) do
    Repo.delete_all(from(rc in "recording_collections", where: rc.collection_id == ^id))
    Repo.delete(collection)
  end

  @doc "Soft-deletes a recording — moves it to the trash rather than destroying it."
  @spec trash_recording(Recording.t()) :: {:ok, Recording.t()} | {:error, Ecto.Changeset.t()}
  def trash_recording(%Recording{} = recording) do
    recording
    |> Ecto.Changeset.change(
      status: :trashed,
      trashed_at: DateTime.truncate(DateTime.utc_now(), :second)
    )
    |> Repo.update()
  end

  @doc "Lists recordings currently in the trash, most recently trashed first."
  @spec list_trashed_recordings() :: [Recording.t()]
  def list_trashed_recordings do
    Recording
    |> where([r], r.status == :trashed)
    |> order_by([r], desc: r.trashed_at, desc: r.id)
    |> Repo.all()
  end

  @doc "Restores a trashed recording back to the working library, exactly as it was."
  @spec restore_recording(Recording.t()) :: {:ok, Recording.t()} | {:error, Ecto.Changeset.t()}
  def restore_recording(%Recording{} = recording) do
    recording
    |> Ecto.Changeset.change(status: :active, trashed_at: nil)
    |> Repo.update()
  end

  @doc """
  Starts live capture on the active `EarWitness.Audio` capture source,
  writing to a new file under the recordings directory. Composes
  `EarWitness.Audio` — `Audio` itself has no knowledge of recordings or
  files.
  """
  @spec start_live_capture() ::
          {:ok, %{ref: reference(), path: Path.t(), channels: [atom()], notice: atom()}}
          | {:error, atom()}
  def start_live_capture do
    path = Path.join(EarWitness.recordings_dir(), Ecto.UUID.generate() <> ".wav")

    case Audio.start_capture(path) do
      {:ok, capture} -> {:ok, Map.put(capture, :path, path)}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc "Stops a running live capture and registers the finished file as a new recording."
  @spec finish_live_capture(reference()) ::
          {:ok, Recording.t(), [atom()]} | {:error, :invalid_audio_file | Ecto.Changeset.t()}
  def finish_live_capture(ref) do
    with {:ok, %{channels: channels, path: path}} <- Audio.stop_capture(ref),
         {:ok, bytes} <- File.read(path),
         {:ok, header} <- WavHeader.parse(bytes) do
      case create_recording(%{
             title: Path.basename(path),
             source: :captured,
             capture_source: capture_source_for(channels),
             file_path: path,
             duration: header.duration_seconds
           }) do
        {:ok, recording} -> {:ok, recording, channels}
        error -> error
      end
    else
      _ -> {:error, :invalid_audio_file}
    end
  end

  # The tap captures both microphone and system audio into one recording
  # (see `Audio.Pipeline.channels_for/1`); a plain microphone capture never
  # includes `:system_audio`, so its presence is what distinguishes a tap
  # capture from a microphone-only one for display purposes.
  defp capture_source_for(channels) do
    if :system_audio in channels, do: :system_audio_tap, else: :microphone
  end

  defp index_for_search({:ok, recording} = result) do
    :ok = Search.index_recording(recording)
    result
  end

  defp index_for_search(error), do: error
end
