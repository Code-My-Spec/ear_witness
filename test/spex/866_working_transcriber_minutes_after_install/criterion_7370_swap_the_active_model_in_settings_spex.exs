defmodule EarWitnessSpex.WorkingTranscriberMinutesAfterInstall.Criterion7370Spex do
  @moduledoc """
  Story 866 — Working transcriber minutes after install
  Criterion 7370: Swap the active model in settings

  Uses `"base"` as the alternative model id — a real whisper.cpp/ggml
  model tier, and also the model the recorded transcription cassette
  (`test/fixtures/transcription_cassettes/vad-f32.json`) was actually
  captured against — rather than a placeholder name.

  Judgment calls made explicit (flag for a human to confirm before
  implementation):

  - The setup route and model-catalog assumptions are those documented on
    `EarWitnessSpex.SetupSteps`; the settings form is
    `EarWitnessSpex.SettingsSteps.switch_active_model/2`.
  - This scenario only covers switching to a model that requires no new
    download (kept in scope to this criterion, not the download flow
    already covered by 7366/7369).
  - The active model is assumed to be readable in Settings via the same
    `[data-test="selected-model"]` element SetupLive uses.
  """

  use EarWitnessSpex.Case

  spex "Swap the active model in settings" do
    scenario "hearing documenter switches from the default model to a different one", context do
      given_ "first-run setup has completed with large-v3-turbo active", context do
        {view, _html} = EarWitnessSpex.SetupSteps.open_setup(context.conn)
        EarWitnessSpex.SetupSteps.start_download(view)
        context
      end

      when_ "they switch the active model to a different one in settings", context do
        view = EarWitnessSpex.SettingsSteps.switch_active_model(context.conn, "base")
        Map.put(context, :view, view)
      end

      then_ "settings now shows the newly chosen model as active", context do
        assert has_element?(context.view, ~s([data-test="selected-model"]), "base")
        :ok
      end

      then_ "the previous model is no longer shown as active", context do
        refute has_element?(context.view, ~s([data-test="selected-model"]), "large-v3-turbo")
        :ok
      end
    end
  end
end
