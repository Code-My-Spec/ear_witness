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
    {:ok, socket |> assign(tap_setup_needed: false) |> reload_settings()}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-6 space-y-8">
      <h1 class="text-2xl font-bold">Settings</h1>

      <div class="card bg-base-100 shadow-sm">
        <div class="card-body">
          <h2 class="card-title">Capture source</h2>
          <p class="text-sm opacity-70">
            Active source: <span data-test="active-capture-source">{source_label(@active_source)}</span>
          </p>

          <form id="capture-source-form" data-test="capture-source-form" phx-change="select_source">
            <label :for={source <- @capture_sources} class="flex items-center gap-2">
              <input
                type="radio"
                name="source"
                value={source_value(source.type)}
                checked={source.type == @active_source}
                class="radio"
              />
              {source.name}
              <span :if={!source.available} class="badge badge-ghost badge-sm">not set up</span>
            </label>
          </form>

          <div :if={@tap_setup_needed} data-test="tap-setup-guide" class="alert alert-warning">
            The system audio tap isn't set up on this machine yet. Install and enable it in your
            operating system's audio settings, then come back and select it here — the tap is
            never activated automatically.
          </div>
        </div>
      </div>

      <div class="card bg-base-100 shadow-sm">
        <div class="card-body">
          <h2 class="card-title">Recording consent policy</h2>
          <p class="text-sm opacity-70">
            Active policy: <span data-test="active-consent-policy">{@consent_policy}</span>
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
                  class="radio"
                />
                {policy.id}
              </label>
              <p data-test="policy-explanation" data-policy={policy.id} class="text-sm opacity-70 pl-6">
                {policy.explanation}
              </p>
            </div>
          </form>

          <div data-test="legal-disclaimer" class="text-xs opacity-60">
            {@policy_disclaimer}
          </div>
        </div>
      </div>

      <div class="card bg-base-100 shadow-sm">
        <div class="card-body">
          <h2 class="card-title">Transcription model</h2>
          <p class="text-sm opacity-70">
            Active model: <span data-test="selected-model">{@active_model_id}</span>
          </p>

          <form
            id="active-model-form"
            data-test="active-model-form"
            phx-change="switch_active_model"
            class="space-y-2"
          >
            <label :for={model <- @downloaded_models} class="flex items-center gap-2">
              <input
                type="radio"
                name="model_id"
                value={model.id}
                checked={model.id == @active_model_id}
                class="radio"
              />
              {model.name}
            </label>
          </form>

          <p :if={@downloaded_models == []} class="text-sm opacity-70">
            No models downloaded yet —
            <.link navigate={~p"/setup"} class="link">finish setup</.link>
            to pick one.
          </p>
        </div>
      </div>

      <div class="card bg-base-100 shadow-sm">
        <div class="card-body">
          <h2 class="card-title">Assistant access</h2>
          <p class="text-sm opacity-70">
            Lets a local AI assistant (via MCP, over stdio — never a network port) search your
            transcripts, read them with speaker/timestamp attribution, and attach summaries.
            Off by default; revoke it any time to instantly cut the assistant off.
          </p>
          <p class="text-sm opacity-70">
            Current status: <span data-test="assistant-access-status">{@assistant_access}</span>
          </p>

          <form
            id="assistant-access-form"
            data-test="assistant-access-form"
            phx-change="set_assistant_access"
          >
            <label :for={value <- [:enabled, :disabled]} class="flex items-center gap-2">
              <input
                type="radio"
                name="access"
                value={value}
                checked={value == @assistant_access}
                class="radio"
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
      {:ok, model} -> {:noreply, assign(socket, active_model_id: model.id)}
      {:error, _reason} -> {:noreply, socket}
    end
  end

  def handle_event("set_assistant_access", %{"access" => access}, socket) do
    {:ok, active} = Assistant.set_access(String.to_existing_atom(access))
    {:noreply, assign(socket, assistant_access: active)}
  end

  defp reload_settings(socket) do
    {policies, disclaimer} = Audio.list_consent_policies()

    assign(socket,
      capture_sources: Audio.list_capture_sources(),
      active_source: Audio.get_active_capture_source(),
      consent_policies: policies,
      policy_disclaimer: disclaimer,
      consent_policy: Audio.get_consent_policy(),
      downloaded_models: Enum.filter(Models.list_models(), &Models.downloaded?(&1.id)),
      active_model_id: active_model_id(),
      assistant_access: Assistant.get_access()
    )
  end

  defp active_model_id do
    case Models.get_active_model() do
      nil -> nil
      model -> model.id
    end
  end

  defp source_value(:microphone), do: "microphone"
  defp source_value(:system_audio_tap), do: "tap"

  defp source_label(:microphone), do: "microphone"
  defp source_label(:system_audio_tap), do: "tap"

  defp parse_source("microphone"), do: :microphone
  defp parse_source("tap"), do: :system_audio_tap
end
