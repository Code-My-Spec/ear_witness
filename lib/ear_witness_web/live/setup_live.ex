defmodule EarWitnessWeb.SetupLive do
  @moduledoc """
  First-run experience — pick a transcription model (size/quality
  guidance), watch it download and verify, and land in a working app
  minutes after install. Once a download's checksum verifies, the model
  becomes the active transcription model automatically — no separate
  "activate" step (story 866, criterion 7367).
  """

  use EarWitnessWeb, :live_view

  alias EarWitness.Models

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Models.subscribe()

    model_id = Models.default_model_id()

    {:ok,
     socket
     |> assign(models: Models.list_models())
     |> assign(selected_model_id: model_id)
     |> assign(downloaded?: Models.downloaded?(model_id))
     |> assign(download_status: Models.download_status(model_id))
     |> assign(recovered_from_error?: false)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-2xl space-y-6">
      <div class="space-y-1">
        <h1 class="text-2xl font-bold">Choose a transcription model</h1>
        <p class="text-sm opacity-70">
          Pick a model to get started — you can change this later in Settings.
        </p>
      </div>

      <div class="space-y-3">
        <div
          :for={model <- @models}
          data-test="model-option"
          data-model-id={model.id}
          phx-click="select_model"
          phx-value-model-id={model.id}
          class={[
            "card cursor-pointer border-2 bg-base-100 shadow-sm transition-colors",
            (model.id == @selected_model_id && "border-primary") || "border-base-300"
          ]}
        >
          <div class="card-body">
            <h2 class="card-title">
              {model.name}
              <span :if={model.default} class="badge badge-primary badge-sm">Recommended</span>
              <span :if={model.bundled} class="badge badge-ghost badge-sm">No download needed</span>
            </h2>
            <p class="text-sm opacity-70">{model.description}</p>
          </div>
        </div>
      </div>

      <div data-test="selected-model" class="text-sm">
        Selected: <span class="font-mono">{@selected_model_id}</span>
      </div>

      <div class="flex flex-wrap items-center gap-4">
        <button
          :if={!@downloaded?}
          data-test="download-button"
          phx-click="start_download"
          class="btn btn-primary"
        >
          <.icon name="hero-arrow-down-tray" class="size-4" /> Download and continue
        </button>

        <button
          :if={@download_status.status == :failed}
          data-test="retry-download-button"
          phx-click="retry_download"
          class="btn btn-outline"
        >
          <.icon name="hero-arrow-path" class="size-4" /> Retry download
        </button>

        <.link :if={@downloaded?} navigate={~p"/recordings"} class="btn btn-primary">
          Continue <.icon name="hero-arrow-right" class="size-4" />
        </.link>
      </div>

      <div data-test="download-progress" class="w-full">
        <progress
          class="progress progress-primary w-full"
          value={@download_status.percent || 0}
          max="100"
        />
      </div>

      <div data-test="download-status" class="text-sm opacity-70">
        {status_text(@download_status, @recovered_from_error?)}
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("select_model", %{"model-id" => model_id}, socket) do
    {:noreply,
     socket
     |> assign(selected_model_id: model_id)
     |> assign(downloaded?: Models.downloaded?(model_id))
     |> assign(download_status: Models.download_status(model_id))
     |> assign(recovered_from_error?: false)}
  end

  def handle_event("start_download", _params, socket) do
    {:noreply,
     socket |> assign(recovered_from_error?: false) |> do_download(&Models.download_model/1)}
  end

  def handle_event("retry_download", _params, socket) do
    {:noreply, do_download(socket, &Models.retry_download/1)}
  end

  @impl true
  def handle_info({:model_download_progress, model_id, progress}, socket) do
    {:noreply,
     socket
     |> maybe_auto_activate(model_id, progress)
     |> maybe_refresh_status(model_id, progress)}
  end

  def handle_info({:active_model_changed, _model}, socket) do
    model_id = socket.assigns.selected_model_id
    {:noreply, assign(socket, downloaded?: Models.downloaded?(model_id))}
  end

  # The transfer runs in the Downloader's own Task; this LiveView awaits
  # its terminal outcome via start_async so the view (and the rest of the
  # app — criterion 7368) stays responsive throughout, while tests can
  # deterministically settle on completion with render_async (7366/7367/
  # 7369/7370). PubSub progress messages keep the bar moving meanwhile.
  defp do_download(socket, download_fun) do
    model_id = socket.assigns.selected_model_id

    case download_fun.(model_id) do
      {:ok, _ref} ->
        socket
        |> assign(download_status: Models.download_status(model_id))
        |> start_async(:await_download, fn ->
          # await_download receives progress via PubSub — this Task must
          # subscribe itself (the LiveView's own subscription doesn't carry
          # over). await_download's terminal pre-check closes the race.
          Models.subscribe()
          Models.await_download(model_id, 30_000)
        end)

      {:error, :already_downloaded} ->
        socket
        |> assign(downloaded?: true)
        |> assign(download_status: Models.download_status(model_id))

      {:error, :unknown_model} ->
        socket
    end
  end

  @impl true
  def handle_async(:await_download, {:ok, status}, socket) do
    {:noreply, apply_terminal_status(socket, socket.assigns.selected_model_id, status)}
  end

  def handle_async(:await_download, {:exit, _reason}, socket) do
    model_id = socket.assigns.selected_model_id
    {:noreply, assign(socket, download_status: Models.download_status(model_id))}
  end

  defp apply_terminal_status(socket, model_id, %{status: :verified} = status) do
    Models.set_active_model(model_id)
    socket |> assign(download_status: status) |> assign(downloaded?: true)
  end

  defp apply_terminal_status(socket, model_id, %{status: :failed} = status) do
    socket
    |> assign(download_status: status)
    |> assign(downloaded?: Models.downloaded?(model_id))
    |> assign(recovered_from_error?: true)
  end

  defp apply_terminal_status(socket, model_id, status) do
    socket
    |> assign(download_status: status)
    |> assign(downloaded?: Models.downloaded?(model_id))
  end

  defp maybe_auto_activate(socket, model_id, %{status: :verified}) do
    case Models.set_active_model(model_id) do
      {:ok, _model} -> socket
      {:error, _reason} -> socket
    end
  end

  defp maybe_auto_activate(socket, _model_id, _progress), do: socket

  defp maybe_refresh_status(socket, model_id, progress) do
    case model_id == socket.assigns.selected_model_id do
      true -> assign(socket, download_status: progress, downloaded?: Models.downloaded?(model_id))
      false -> socket
    end
  end

  defp status_text(%{status: :not_started}, _recovered?), do: "Not started"

  defp status_text(%{status: :downloading, percent: percent}, _recovered?) do
    "Downloading… #{percent || 0}%"
  end

  defp status_text(%{status: :verifying}, _recovered?), do: "Verifying checksum…"

  defp status_text(%{status: :verified}, true),
    do: "Recovered from a network interruption. Verified."

  defp status_text(%{status: :verified}, false), do: "Verified"

  defp status_text(%{status: :failed, error: :network_interrupted}, _recovered?) do
    "Failed: network interruption. Retry to continue."
  end

  defp status_text(%{status: :failed, error: reason}, _recovered?),
    do: "Failed: #{inspect(reason)}"
end
