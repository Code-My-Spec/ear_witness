defmodule EarWitnessSpex.WorkingTranscriberMinutesAfterInstall.Criterion7368Spex do
  @moduledoc """
  Story 866 — Working transcriber minutes after install
  Criterion 7368: Record a meeting during the download

  Proves the download doesn't block the rest of the app: this spec
  asserts the download is still genuinely in progress (not already
  finished) before starting a capture, then starts a capture on a
  completely separate route (`/recordings`) and asserts it isn't refused
  or queued behind the download — mirroring how criterion 7329 proves
  transcription doesn't block the rest of the app.

  Judgment calls made explicit (flag for a human to confirm before
  implementation):

  - The setup route and model-catalog assumptions are those documented on
    `EarWitnessSpex.SetupSteps`.
  - `[data-test="download-status"]` is assumed to show text distinct from
    "Verified" (e.g. some in-progress wording) while a download is still
    running, so this spec can anchor on "not finished yet" without
    depending on the exact in-progress copy.
  - Capture is staged the same way story 861's specs stage it: consent
    policy "silent" and the tap as capture source, chosen through the
    real settings UI.
  """

  use EarWitnessSpex.Case

  spex "Record a meeting during the download" do
    scenario "new user starts recording a meeting while the model is still downloading",
             context do
      given_ "a model download is in progress and not yet finished", context do
        # The gate holds the transfer genuinely mid-flight (like a real
        # multi-gigabyte model file) — released automatically on exit.
        EarWitnessSpex.Fixtures.hold_model_downloads()

        {view, _html} = EarWitnessSpex.SetupSteps.open_setup(context.conn)
        html = EarWitnessSpex.SetupSteps.start_download_without_waiting(view)

        context
        |> Map.put(:setup_view, view)
        |> Map.put(:setup_html, html)
      end

      when_ "they navigate to the recordings library and start a live capture", context do
        EarWitnessSpex.SettingsSteps.choose_consent_policy(context.conn, "silent")
        EarWitnessSpex.SettingsSteps.choose_tap_capture_source(context.conn)

        {:ok, view, _html} = live(context.conn, "/recordings")
        html = view |> element("button", "Record") |> render_click()

        context
        |> Map.put(:view, view)
        |> Map.put(:html, html)
      end

      then_ "recording begins normally, not refused or queued behind the download", context do
        assert has_element?(context.view, ~s([data-test="capture-status"]), "recording")
        refute has_element?(context.view, ~s([data-test="capture-error"]))
        :ok
      end

      then_ "the download was still running when the capture started, proving it didn't block",
            context do
        refute has_element?(context.setup_view, ~s([data-test="download-status"]), "Verified")
        EarWitnessSpex.Fixtures.release_model_downloads()
        :ok
      end
    end
  end
end
