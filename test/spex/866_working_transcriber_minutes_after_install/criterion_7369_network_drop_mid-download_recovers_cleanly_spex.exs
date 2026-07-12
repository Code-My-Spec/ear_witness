defmodule EarWitnessSpex.WorkingTranscriberMinutesAfterInstall.Criterion7369Spex do
  @moduledoc """
  Story 866 — Working transcriber minutes after install
  Criterion 7369: Network drop mid-download recovers cleanly

  Injecting a genuine network failure partway through an HTTP transfer
  isn't stageable through the real UI — the download seam
  (`EarWitness.Models.Downloader`, a hand-written `Req` client per the
  `req_cassette` ADR) doesn't exist yet. This uses the same honest-raising
  stub pattern as story 861's `simulate_announcement_delivery_failure`
  and story 862/863's diarization stubs:
  `EarWitnessSpex.Fixtures.simulate_download_network_interruption/0`.
  Keeps this spec red at the first step; the `when_`/`then_` steps below
  still encode the full recovery flow as it would run once the seam
  lands.

  Judgment calls made explicit (flag for a human to confirm before
  implementation):

  - The setup route and model-catalog assumptions are those documented on
    `EarWitnessSpex.SetupSteps`.
  - "Recovers cleanly" is read as: the interruption surfaces a clear,
    non-crashing error state with a retry control
    (`[data-test="retry-download-button"]`), and retrying resumes the
    same download to a successful, checksum-verified completion — not
    that it silently auto-retries with no user-visible state change.
  - No partial or corrupt model is assumed to become the active model at
    any point during the interruption.
  """

  use EarWitnessSpex.Case

  spex "Network drop mid-download recovers cleanly" do
    scenario "new user's download is interrupted by a network drop and they retry it",
             context do
      given_ "a model download is interrupted by a network drop partway through", context do
        EarWitnessSpex.Fixtures.simulate_download_network_interruption()

        {view, _html} = EarWitnessSpex.SetupSteps.open_setup(context.conn)
        EarWitnessSpex.SetupSteps.start_download(view)

        Map.put(context, :view, view)
      end

      when_ "they retry the download", context do
        context.view
        |> element(~s([data-test="retry-download-button"]))
        |> render_click()

        # The download is async (start_async) — settle on its terminal
        # state before asserting, mirroring SetupSteps.start_download/1.
        html = render_async(context.view, 30_000)

        Map.put(context, :html, html)
      end

      then_ "the interruption was reported clearly rather than crashing or hanging silently",
            context do
        assert has_element?(context.view, ~s([data-test="download-status"]), "network")
        :ok
      end

      then_ "the retried download completes and is checksum-verified", context do
        assert has_element?(context.view, ~s([data-test="download-status"]), "Verified")
        :ok
      end

      then_ "the model that ends up active is the one that was actually verified, not a partial file",
            context do
        assert has_element?(context.view, ~s([data-test="selected-model"]), "large-v3-turbo")
        :ok
      end
    end
  end
end
