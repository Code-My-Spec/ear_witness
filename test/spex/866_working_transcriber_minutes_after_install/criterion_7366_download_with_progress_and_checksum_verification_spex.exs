defmodule EarWitnessSpex.WorkingTranscriberMinutesAfterInstall.Criterion7366Spex do
  @moduledoc """
  Story 866 — Working transcriber minutes after install
  Criterion 7366: Download with progress and checksum verification

  Drives the real download button; the HTTP transfer itself runs behind
  `EarWitness.Models.Downloader` (a hand-written `Req` client per the
  `req_cassette` ADR), which is the implementer's seam to wire up — this
  spec only pins the UI contract: progress is observable while the
  download runs, and completion is gated on checksum verification rather
  than just "bytes arrived."

  Judgment calls made explicit (flag for a human to confirm before
  implementation):

  - The setup route and model-catalog assumptions are those documented on
    `EarWitnessSpex.SetupSteps`.
  - `[data-test="download-progress"]` is assumed to render for the whole
    lifetime of a download, including after it completes (showing its
    final value) — this spec only asserts it is present, not that it is
    still advancing, since Oban's `testing: :inline` setting (see the
    background-jobs ADR) means a triggering `render_click` observed
    elsewhere in this suite runs a job to completion before returning.
  - Successful completion is assumed to be reported via
    `[data-test="download-status"]` containing the word "Verified" —
    distinguishing "downloaded" from "downloaded and checksum-verified."
  """

  use EarWitnessSpex.Case

  spex "Download with progress and checksum verification" do
    scenario "new user downloads the preselected model and watches it verify", context do
      given_ "this is a fresh install on the model picker", context do
        {view, _html} = EarWitnessSpex.SetupSteps.open_setup(context.conn)
        Map.put(context, :view, view)
      end

      when_ "they start the download", context do
        html = EarWitnessSpex.SetupSteps.start_download(context.view)
        Map.put(context, :html, html)
      end

      then_ "download progress is shown while it runs", context do
        assert has_element?(context.view, ~s([data-test="download-progress"]))
        :ok
      end

      then_ "once complete, the model is reported as checksum-verified", context do
        assert has_element?(context.view, ~s([data-test="download-status"]), "Verified")
        :ok
      end
    end
  end
end
