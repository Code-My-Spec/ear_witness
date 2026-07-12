defmodule EarWitnessSpex.SetupSteps do
  @moduledoc """
  Reusable steps for driving `EarWitnessWeb.SetupLive` from BDD specs
  (story 866). Every call here goes through the real LiveView surface —
  nothing here reaches into `EarWitness.*` contexts, `Repo`, `File`, or
  `Port` (see the local Credo check `EARWIT0001`).

  ## Route assumption

  `EarWitnessWeb.SetupLive` doesn't exist yet. This helper assumes it is
  reachable at `/setup`, mirroring the other top-level LiveViews already
  assumed elsewhere (`/recordings`, `/settings`) — a judgment call made
  explicit here so a human can correct it (and this one helper) before
  implementation; every story 866 spec goes through this function rather
  than hard-coding the path itself.

  ## Model catalog assumption

  Specs reference two real whisper.cpp/ggml model tiers by id:
  `"large-v3-turbo"` (the criterion 7365 preselected default) and
  `"base"` (a smaller alternative — also the model the recorded
  transcription cassette, `test/fixtures/transcription_cassettes/vad-f32.json`,
  was actually captured against). Whether the real catalog includes
  additional models is not assumed either way.
  """

  @endpoint EarWitnessWeb.Endpoint

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  @doc "Opens the first-run setup page. Returns `{view, html}`."
  def open_setup(conn) do
    {:ok, view, html} = live(conn, "/setup")
    {view, html}
  end

  @doc """
  Selects `model_id` in the model picker
  (`[data-test="model-option"][data-model-id="..."]`). Returns the
  rendered HTML after the selection.
  """
  def select_model(view, model_id) do
    view
    |> element(~s([data-test="model-option"][data-model-id="#{model_id}"]))
    |> render_click()
  end

  @doc """
  Starts the download of the currently selected model
  (`[data-test="download-button"]`) and waits for the async download to
  reach a terminal state (`render_async/2` on the LiveView's
  `start_async(:await_download, ...)`). Returns the settled HTML.

  Criterion 7368 ("record during the download") deliberately does NOT use
  this helper — it clicks the button directly and gates the transfer via
  `EarWitnessSpex.Fixtures.hold_model_downloads/0` so the download is
  genuinely still in flight.
  """
  def start_download(view) do
    view |> element(~s([data-test="download-button"])) |> render_click()
    render_async(view, 30_000)
  end

  @doc """
  Clicks the download button WITHOUT waiting for completion — for specs
  that need the download genuinely mid-flight (criterion 7368). Pair with
  `EarWitnessSpex.Fixtures.hold_model_downloads/0`.
  """
  def start_download_without_waiting(view) do
    view |> element(~s([data-test="download-button"])) |> render_click()
  end
end
