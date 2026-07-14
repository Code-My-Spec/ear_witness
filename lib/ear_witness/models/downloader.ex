defmodule EarWitness.Models.Downloader do
  @moduledoc """
  Fetches a model's file over HTTP — a hand-written `Req` client, per the
  `req_cassette` ADR (`.code_my_spec/architecture/decisions/req_cassette.md`)
  — verifies it against a known checksum before the file is considered
  usable, and reports progress as it runs. Each transfer runs in a
  supervised `Task` so the caller (`EarWitness.Models.download_model/1`)
  never blocks on the network. A checksum mismatch or a failed transfer
  never leaves a partial file at the final destination path — only a
  verified file is ever renamed into place.

  Holds no durable state of its own: a download's status lives only for
  the lifetime of this GenServer. `EarWitness.Models.downloaded?/1` treats
  a verified file already on disk (matching checksum) as downloaded even
  when this process has no memory of the transfer, so a restarted app
  still recognizes what it already has.

  Tests replay a recorded HTTP interaction via `ReqCassette` instead of
  hitting the network — see `config/test.exs` (`plug:` for this module)
  and `test/cassettes/models/large_v3_turbo_download.json`, which stands
  in for the real (multi-gigabyte) model file with a small fixture.
  """

  use GenServer

  @topic "models"

  @type status :: :not_started | :downloading | :verifying | :verified | :failed
  @type progress :: %{status: status(), percent: non_neg_integer() | nil, error: term() | nil}

  # Client API

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @doc """
  Starts a verified download of `url` to `dest_path`, checked against
  `checksum` (lowercase hex-encoded SHA-256). Returns immediately; the
  transfer runs in the background and reports progress over PubSub (see
  `subscribe/0`).
  """
  @spec start(String.t(), String.t(), String.t(), Path.t()) :: {:ok, reference()}
  def start(model_id, url, checksum, dest_path) do
    GenServer.call(__MODULE__, {:start, model_id, url, checksum, dest_path})
  end

  @doc "The current status of a model's download (`:not_started` if never attempted)."
  @spec status(String.t()) :: progress()
  def status(model_id), do: GenServer.call(__MODULE__, {:status, model_id})

  @doc "Subscribes the caller to `EarWitness.Models` PubSub notifications (progress and active-model changes)."
  @spec subscribe() :: :ok
  def subscribe, do: Phoenix.PubSub.subscribe(EarWitness.PubSub, @topic)

  # Server callbacks

  @impl true
  def init(_opts), do: {:ok, %{progress: %{}}}

  @impl true
  def handle_call({:start, model_id, url, checksum, dest_path}, _from, state) do
    ref = make_ref()
    state = put_progress(state, model_id, %{status: :downloading, percent: 0, error: nil})
    broadcast(model_id, state)

    Task.Supervisor.start_child(EarWitness.Models.TaskSupervisor, fn ->
      transfer(model_id, url, checksum, dest_path)
    end)

    {:reply, {:ok, ref}, state}
  end

  def handle_call({:status, model_id}, _from, state) do
    {:reply, progress_for(state, model_id), state}
  end

  @impl true
  def handle_cast({:progress, model_id, progress}, state) do
    state = put_progress(state, model_id, progress)
    broadcast(model_id, state)
    {:noreply, state}
  end

  # Transfer — runs inside the spawned Task, off the GenServer.

  defp transfer(model_id, url, checksum, dest_path) do
    partial_path = dest_path <> ".partial"

    with :ok <- simulate_interruption(),
         :ok <- File.mkdir_p(Path.dirname(dest_path)),
         :ok <- fetch_to_file(model_id, url, partial_path),
         :ok <- report(model_id, %{status: :verifying, percent: 100, error: nil}),
         true <- checksum_of(partial_path) == checksum,
         :ok <- File.rename(partial_path, dest_path) do
      report(model_id, %{status: :verified, percent: 100, error: nil})
    else
      false ->
        File.rm(partial_path)
        report(model_id, %{status: :failed, percent: nil, error: :checksum_mismatch})

      {:error, reason} ->
        File.rm(partial_path)
        report(model_id, %{status: :failed, percent: nil, error: reason})
    end
  end

  # Streams the body to `partial_path` in chunks, reporting incremental percent
  # from Content-Length as it arrives — so a multi-gigabyte model shows real
  # progress instead of sitting at 0% until the whole file lands, and the file
  # is never held in memory. Progress is only reported when the whole-number
  # percent changes, so a large download doesn't flood PubSub.
  defp fetch_to_file(model_id, url, partial_path) do
    file = File.open!(partial_path, [:write, :binary])

    collector = fn {:data, data}, {req, resp} ->
      # Req streams intermediate redirect (3xx) response bodies into the SAME
      # `into:` collector before following them — HuggingFace's `/resolve/main/`
      # URL 302s to a signed CDN link, and that redirect page ("Found.
      # Redirecting to …", ~1KB of text) would otherwise be written to the file
      # ahead of the model bytes, corrupting it and failing the checksum (the
      # streamed model body itself hashes correctly). Only the final 200 body is
      # the file, so skip anything else.
      if resp.status == 200 do
        :ok = IO.binwrite(file, data)
        downloaded = (resp.private[:downloaded] || 0) + byte_size(data)
        resp = put_in(resp.private[:downloaded], downloaded)

        {:cont, {req, maybe_report_progress(model_id, resp, downloaded)}}
      else
        {:cont, {req, resp}}
      end
    end

    try do
      case Req.get(url, [into: collector] ++ req_opts()) do
        {:ok, %Req.Response{status: 200}} -> :ok
        {:ok, %Req.Response{status: status}} -> {:error, {:http_error, status}}
        {:error, reason} -> {:error, reason}
      end
    after
      File.close(file)
    end
  end

  defp maybe_report_progress(model_id, resp, downloaded) do
    case content_length(resp) do
      nil ->
        resp

      total ->
        pct = percent(downloaded, total)

        if pct != resp.private[:last_pct] do
          report(model_id, %{status: :downloading, percent: pct, error: nil})
          put_in(resp.private[:last_pct], pct)
        else
          resp
        end
    end
  end

  defp content_length(resp) do
    case Req.Response.get_header(resp, "content-length") do
      [len | _] -> String.to_integer(len)
      _ -> nil
    end
  end

  # Cap at 99 during transfer — 100 is reserved for verify/verified, so the bar
  # never reads "100%" while the checksum is still being computed.
  defp percent(_downloaded, total) when total <= 0, do: 0
  defp percent(downloaded, total), do: min(99, div(downloaded * 100, total))

  defp req_opts do
    case Application.get_env(:ear_witness, __MODULE__, []) |> Keyword.get(:plug) do
      nil -> []
      plug -> [plug: plug]
    end
  end

  # Test-only seam: EarWitnessSpex.Fixtures.simulate_download_network_interruption/0
  # flips this once (consumed on read) so the very next transfer fails
  # before hitting the network, the way a real dropped connection would —
  # see story 866, criterion 7369.
  defp simulate_interruption do
    case Application.get_env(:ear_witness, :models_downloader_network_override) do
      :interrupt ->
        Application.delete_env(:ear_witness, :models_downloader_network_override)
        {:error, :network_interrupted}

      _ ->
        :ok
    end
  end

  defp checksum_of(path) do
    path
    |> File.read!()
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  defp report(model_id, progress) do
    GenServer.cast(__MODULE__, {:progress, model_id, progress})
    :ok
  end

  defp put_progress(state, model_id, progress) do
    %{state | progress: Map.put(state.progress, model_id, progress)}
  end

  defp progress_for(state, model_id) do
    Map.get(state.progress, model_id, %{status: :not_started, percent: nil, error: nil})
  end

  defp broadcast(model_id, state) do
    Phoenix.PubSub.broadcast(
      EarWitness.PubSub,
      @topic,
      {:model_download_progress, model_id, progress_for(state, model_id)}
    )
  end
end
