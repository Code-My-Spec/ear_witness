defmodule EarWitnessWeb.Router do
  use EarWitnessWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {EarWitnessWeb.LayoutView, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", EarWitnessWeb do
    pipe_through :browser

    # "/" now opens the recordings library — RecordingLive supersedes
    # TodoLive as the app's primary surface (see the architecture
    # proposal). TodoLive stays reachable at /legacy-todo during the
    # transition rather than being deleted outright.
    live "/", RecordingLive.Index, :index
    live "/recordings", RecordingLive.Index, :index
    live "/recordings/trash", RecordingLive.Index, :trash
    live "/recordings/:id", RecordingLive.Show, :show
    live "/recordings/:id/transcript", TranscriptLive.Editor, :show
    live "/search", SearchLive
    live "/settings", SettingsLive
    live "/setup", SetupLive
    live "/legacy-todo", TodoLive
  end
end
