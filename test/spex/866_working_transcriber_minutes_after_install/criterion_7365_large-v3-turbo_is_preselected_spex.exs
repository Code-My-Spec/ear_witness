defmodule EarWitnessSpex.WorkingTranscriberMinutesAfterInstall.Criterion7365Spex do
  @moduledoc """
  Story 866 — Working transcriber minutes after install
  Criterion 7365: large-v3-turbo is preselected

  Asserts the picker's default selection is the real model id
  `"large-v3-turbo"` (a genuine whisper.cpp/ggml model tier), not a
  placeholder — see `EarWitnessSpex.SetupSteps` for the model-catalog
  assumption.

  Judgment call made explicit: the current selection is assumed to be
  reflected in a single `[data-test="selected-model"]` element (rather
  than, say, a `:checked` attribute scattered across each option) so a
  spec can assert "what's selected" without depending on picker markup
  details — flag for a human to confirm before implementation.
  """

  use EarWitnessSpex.Case

  spex "large-v3-turbo is preselected" do
    scenario "new user opens the model picker without choosing anything yet", context do
      given_ "this is a fresh install with no model downloaded yet", context do
        context
      end

      when_ "they open the app", context do
        {view, html} = EarWitnessSpex.SetupSteps.open_setup(context.conn)

        context
        |> Map.put(:view, view)
        |> Map.put(:html, html)
      end

      then_ "large-v3-turbo is already shown as the selected model", context do
        assert has_element?(context.view, ~s([data-test="selected-model"]), "large-v3-turbo")
        :ok
      end
    end
  end
end
