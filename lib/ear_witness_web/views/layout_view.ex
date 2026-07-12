defmodule EarWitnessWeb.LayoutView do
  use EarWitnessWeb, :view

  alias EarWitness.Models
  alias Phoenix.LiveView.JS

  @doc """
  Whether the first-run Setup nav link should show — true whenever no
  transcription model is active yet, mirroring `SetupLive`'s own gate
  (story 866). Once a model is downloaded and verified, `SetupLive`
  activates it automatically and Setup drops out of the persistent nav.
  """
  @spec setup_needed?() :: boolean()
  def setup_needed?, do: is_nil(Models.get_active_model())

  @doc """
  Light/dark/system theme toggle, same idiom (and `<head>` bootstrap
  script in `root.html.heex`) as `code_my_spec` and `get_ai_traffic`.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="card relative flex flex-row items-center border-2 border-base-300 bg-base-300 rounded-full">
      <div class="absolute w-1/3 h-full rounded-full border-1 border-base-200 bg-base-100 brightness-200 left-0 [[data-theme=light]_&]:left-1/3 [[data-theme=dark]_&]:left-2/3 transition-[left]" />

      <button
        phx-click={JS.dispatch("phx:set-theme", detail: %{theme: "system"})}
        class="flex p-2 cursor-pointer w-1/3"
        aria-label="Use system theme"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        phx-click={JS.dispatch("phx:set-theme", detail: %{theme: "light"})}
        class="flex p-2 cursor-pointer w-1/3"
        aria-label="Use light theme"
      >
        <.icon name="hero-sun-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        phx-click={JS.dispatch("phx:set-theme", detail: %{theme: "dark"})}
        class="flex p-2 cursor-pointer w-1/3"
        aria-label="Use dark theme"
      >
        <.icon name="hero-moon-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end
end
