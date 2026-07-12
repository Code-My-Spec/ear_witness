defmodule EarWitnessSpex.WorkingTranscriberMinutesAfterInstall.Criterion7364Spex do
  @moduledoc """
  Story 866 — Working transcriber minutes after install
  Criterion 7364: Fresh install greets the user with a model picker

  A fresh DB sandbox with nothing seeded already stands in for "no model
  downloaded yet" — no fixture or stub needed to establish that.

  Judgment calls made explicit (flag for a human to confirm before
  implementation):

  - The setup route and model-catalog assumptions are those documented on
    `EarWitnessSpex.SetupSteps`.
  - The picker is assumed to render one `[data-test="model-option"]` per
    known model, each carrying its own `data-model-id`.
  """

  use EarWitnessSpex.Case

  spex "Fresh install greets the user with a model picker" do
    scenario "new user launches the app for the first time", context do
      given_ "this is a fresh install with no model downloaded yet", context do
        context
      end

      when_ "they open the app", context do
        {view, html} = EarWitnessSpex.SetupSteps.open_setup(context.conn)

        context
        |> Map.put(:view, view)
        |> Map.put(:html, html)
      end

      then_ "they are greeted with a model picker rather than the recordings library", context do
        assert has_element?(context.view, ~s([data-test="model-option"]))
        refute context.html =~ ~s(data-test="recording-row")
        :ok
      end

      then_ "more than one model is offered", context do
        options = Regex.scan(~r/data-test="model-option"/, context.html)
        assert length(options) > 1
        :ok
      end
    end
  end
end
