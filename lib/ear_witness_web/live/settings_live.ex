defmodule EarWitnessWeb.SettingsLive do
  @moduledoc """
  Capture settings — pick the active capture source (microphone or the
  system audio tap) and the recording consent/notification policy, with
  a plain-language explanation of what each policy means and guided
  setup when the tap isn't available on this machine.
  """

  use EarWitnessWeb, :live_view

  alias EarWitness.{Assistant, Audio, Models}

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Models.subscribe()
    {:ok, socket |> assign(tap_setup_needed: false) |> reload_settings()}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-8">
      <h1 class="text-2xl font-bold">Settings</h1>

      <div class="card bg-base-100 border border-base-300 shadow-sm">
        <div class="card-body">
          <h2 class="card-title">
            <.icon name="hero-microphone" class="size-5 text-primary" /> Capture source
          </h2>
          <p class="text-sm opacity-70">
            Active source: <span data-test="active-capture-source" class="font-medium">{source_label(@active_source)}</span>
          </p>

          <form id="capture-source-form" data-test="capture-source-form" phx-change="select_source" class="space-y-3">
            <div
              :for={source <- @capture_sources}
              data-test="capture-source-option"
              data-source={source_value(source.type)}
            >
              <label class="flex items-center gap-2">
                <input
                  type="radio"
                  name="source"
                  value={source_value(source.type)}
                  checked={source.type == @active_source}
                  class="radio radio-sm"
                />
                {source.name}
                <span :if={!source.available} class="badge badge-ghost badge-sm">not set up</span>
              </label>
              <p data-test="capture-source-help" class="pl-6 text-sm opacity-70">
                {source_description(source.type)}
              </p>
            </div>
          </form>

          <div :if={@tap_setup_needed} data-test="tap-setup-guide" class="alert alert-warning">
            <.icon name="hero-exclamation-triangle" class="size-5" />
            The system audio tap isn't set up on this machine yet. Install and enable it in your
            operating system's audio settings, then come back and select it here — the tap is
            never activated automatically.
          </div>
        </div>
      </div>

      <div class="card bg-base-100 border border-base-300 shadow-sm">
        <div class="card-body">
          <h2 class="card-title">
            <.icon name="hero-shield-check" class="size-5 text-primary" /> Recording consent policy
          </h2>
          <p class="text-sm opacity-70">
            Active policy: <span data-test="active-consent-policy" class="font-medium">{@consent_policy}</span>
          </p>

          <form
            id="consent-policy-form"
            data-test="consent-policy-form"
            phx-change="select_policy"
            class="space-y-2"
          >
            <div :for={policy <- @consent_policies} data-test="policy-option" data-policy={policy.id}>
              <label class="flex items-center gap-2">
                <input
                  type="radio"
                  name="policy"
                  value={policy.id}
                  checked={policy.id == @consent_policy}
                  class="radio radio-sm"
                />
                {policy.id}
              </label>
              <p data-test="policy-explanation" data-policy={policy.id} class="pl-6 text-sm opacity-70">
                {policy.explanation}
              </p>
            </div>
          </form>

          <div data-test="legal-disclaimer" class="text-xs opacity-60">
            {@policy_disclaimer}
          </div>
        </div>
      </div>

      <div class="card bg-base-100 border border-base-300 shadow-sm">
        <div class="card-body">
          <h2 class="card-title">
            <.icon name="hero-cpu-chip" class="size-5 text-primary" /> Transcription model
          </h2>
          <p class="text-sm opacity-70">
            Active model: <span data-test="selected-model" class="font-mono">{@active_model_id}</span>
          </p>

          <div class="space-y-2">
            <div
              :for={row <- @models}
              data-test="model-row"
              data-model={row.model.id}
              class="flex items-start justify-between gap-3 rounded-lg border border-base-300 p-3"
            >
              <div class="min-w-0">
                <div class="flex flex-wrap items-center gap-2">
                  <span class="font-medium">{row.model.name}</span>
                  <span :if={row.active} class="badge badge-primary badge-sm">Active</span>
                  <span :if={row.model.bundled} class="badge badge-ghost badge-sm">Bundled</span>
                </div>
                <p class="text-sm opacity-70">{row.model.description}</p>
                <p class="text-xs opacity-50">{format_size(row.model.size_bytes)}</p>
                <p
                  :if={row.status == :failed}
                  data-test="model-error"
                  class="text-xs text-error"
                >
                  Download failed — try again.
                </p>
              </div>

              <div class="flex shrink-0 items-center gap-2">
                <span
                  :if={row.status in [:downloading, :verifying]}
                  data-test="model-progress"
                  class="tnum text-sm opacity-70"
                >
                  {if row.status == :verifying, do: "Verifying…", else: "#{row.percent || 0}%"}
                </span>

                <button
                  :if={row.downloaded and not row.active}
                  type="button"
                  data-test="use-model"
                  data-model={row.model.id}
                  phx-click="switch_active_model"
                  phx-value-model_id={row.model.id}
                  class="btn btn-primary btn-sm"
                >
                  Use
                </button>

                <button
                  :if={not row.downloaded and row.status not in [:downloading, :verifying]}
                  type="button"
                  data-test="download-model"
                  data-model={row.model.id}
                  phx-click="download_model"
                  phx-value-model_id={row.model.id}
                  class="btn btn-outline btn-sm"
                >
                  {if row.status == :failed, do: "Retry", else: "Download"}
                </button>

                <button
                  :if={row.downloaded and not row.model.bundled}
                  type="button"
                  data-test="delete-model"
                  data-model={row.model.id}
                  phx-click="delete_model"
                  phx-value-model_id={row.model.id}
                  class="btn btn-ghost btn-sm"
                >
                  Delete
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>

      <div class="card bg-base-100 border border-base-300 shadow-sm">
        <div class="card-body">
          <h2 class="card-title">
            <.icon name="hero-command-line" class="size-5 text-primary" /> Assistant access
          </h2>
          <p class="text-sm opacity-70">
            Lets a local AI assistant (via MCP, over stdio — never a network port) search your
            transcripts, read them with speaker/timestamp attribution, and attach summaries.
            Off by default; revoke it any time to instantly cut the assistant off.
          </p>
          <p class="text-sm opacity-70">
            Current status: <span data-test="assistant-access-status" class="font-medium">{@assistant_access}</span>
          </p>

          <form
            id="assistant-access-form"
            data-test="assistant-access-form"
            phx-change="set_assistant_access"
            class="space-y-1"
          >
            <label :for={value <- [:enabled, :disabled]} class="flex items-center gap-2">
              <input
                type="radio"
                name="access"
                value={value}
                checked={value == @assistant_access}
                class="radio radio-sm"
              />
              {value}
            </label>
          </form>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("select_source", %{"source" => source}, socket) do
    case Audio.set_active_capture_source(parse_source(source)) do
      {:ok, active} ->
        {:noreply,
         socket
         |> assign(active_source: active, tap_setup_needed: false)
         |> assign(capture_sources: Audio.list_capture_sources())}

      {:error, :source_unavailable} ->
        {:noreply,
         socket
         |> assign(tap_setup_needed: parse_source(source) == :system_audio_tap)
         |> assign(capture_sources: Audio.list_capture_sources())}
    end
  end

  def handle_event("select_policy", %{"policy" => policy}, socket) do
    {:ok, active} = Audio.set_consent_policy(String.to_existing_atom(policy))
    {:noreply, assign(socket, consent_policy: active)}
  end

  def handle_event("switch_active_model", %{"model_id" => model_id}, socket) do
    case Models.set_active_model(model_id) do
      {:ok, model} -> {:noreply, socket |> assign(active_model_id: model.id) |> assign_models()}
      {:error, _reason} -> {:noreply, socket}
    end
  end

  def handle_event("download_model", %{"model_id" => model_id}, socket) do
    Models.download_model(model_id)
    {:noreply, assign_models(socket)}
  end

  def handle_event("delete_model", %{"model_id" => model_id}, socket) do
    Models.delete_model(model_id)
    {:noreply, socket |> assign(active_model_id: active_model_id()) |> assign_models()}
  end

  def handle_event("set_assistant_access", %{"access" => access}, socket) do
    {:ok, active} = Assistant.set_access(String.to_existing_atom(access))
    {:noreply, assign(socket, assistant_access: active)}
  end

  # Any catalog/download/active-model change on the "models" topic just
  # refreshes the rendered model rows (progress %, verified, active).
  @impl true
  def handle_info({:model_download_progress, _model_id, _progress}, socket) do
    {:noreply, socket |> assign(active_model_id: active_model_id()) |> assign_models()}
  end

  def handle_info({:active_model_changed, _model}, socket) do
    {:noreply, socket |> assign(active_model_id: active_model_id()) |> assign_models()}
  end

  def handle_info({:model_deleted, _model}, socket) do
    {:noreply, socket |> assign(active_model_id: active_model_id()) |> assign_models()}
  end

  def handle_info(_msg, socket), do: {:noreply, socket}

  defp reload_settings(socket) do
    {policies, disclaimer} = Audio.list_consent_policies()

    socket
    |> assign(
      capture_sources: Audio.list_capture_sources(),
      active_source: Audio.get_active_capture_source(),
      consent_policies: policies,
      policy_disclaimer: disclaimer,
      consent_policy: Audio.get_consent_policy(),
      active_model_id: active_model_id(),
      assistant_access: Assistant.get_access()
    )
    |> assign_models()
  end

  # One row per catalog model with its live state, so Settings is a full
  # model manager (download / delete / pick active) rather than a picker
  # over only already-downloaded models.
  defp assign_models(socket) do
    active = active_model_id()

    rows =
      Enum.map(Models.list_models(), fn model ->
        %{status: status, percent: percent} = Models.download_status(model.id)

        %{
          model: model,
          downloaded: Models.downloaded?(model.id),
          active: model.id == active,
          status: status,
          percent: percent
        }
      end)

    assign(socket, models: rows)
  end

  defp active_model_id do
    case Models.get_active_model() do
      nil -> nil
      model -> model.id
    end
  end

  defp format_size(bytes) when bytes >= 1_000_000_000,
    do: "#{Float.round(bytes / 1_000_000_000, 1)} GB"

  defp format_size(bytes) when bytes >= 1_000_000,
    do: "#{round(bytes / 1_000_000)} MB"

  defp format_size(bytes), do: "#{round(bytes / 1_000)} KB"

  defp source_value(:microphone), do: "microphone"
  defp source_value(:system_audio_tap), do: "tap"

  defp source_description(:microphone),
    do:
      "Records your default microphone — your own voice and whatever else the mic " <>
        "picks up in the room."

  defp source_description(:system_audio_tap),
    do:
      "Records everything your computer plays out loud — both sides of a call, videos, " <>
        "any app's sound. It taps your whole system output, so there's no single device " <>
        "to pick; whatever you hear is what gets recorded."

  defp source_label(:microphone), do: "microphone"
  defp source_label(:system_audio_tap), do: "tap"

  defp parse_source("microphone"), do: :microphone
  defp parse_source("tap"), do: :system_audio_tap
end
