defmodule EarWitnessSpex.SendABotToTheMeetingsICantAttend.Criterion7386Spex do
  @moduledoc """
  Story 869 — Send a bot to the meetings I can't attend
  Criterion 7386: Bot recordings get transcripts and speakers automatically

  This is the mirror image of story 860/criterion 7332 ("Imported
  recording waits for an explicit transcribe action"): imported and
  tap-captured recordings wait for the user to press Transcribe, but a
  bot recording is claimed to flow straight through the normal
  transcription/speaker-diarization pipeline on its own. The precondition
  — a bot recording already sitting in the library — is staged with
  `EarWitnessSpex.Fixtures.simulate_bot_join_completed/1` (same
  honestly-raising stub used by criterion 7385, since real join/record/
  leave cannot be driven from a spec). This spec's own action is simply
  opening that recording without touching any transcribe control, then
  asserting the transcript and speaker attribution are already there —
  produced by the SUT, not seeded by this spec.

  Only presence/structure is asserted (real transcript + real per-segment
  speaker attribution), not exact wording — the recorded-response engine
  and diarizer (see the project BDD plan's seams section) produce
  whatever text/labels correspond to the fixture audio the eventual
  `Bots.Runner` implementation hands off, which this spec does not
  control.

  Judgment calls made explicit (flag for a human to confirm before
  implementation):

  - The dispatch route/form/selector assumptions are those documented
    on `EarWitnessSpex.BotSteps`; `[data-test="transcript"]`,
    `[data-test="transcribe-button"]`, and `[data-test="segment-speaker"]`
    are the existing selectors from stories 860/862 (see the project BDD
    plan's selector-conventions section).
  - The library index's `href="/recordings/:id"` link (read the same way
    `EarWitnessSpex.RecordingSteps.import_wav/3` reads it) is assumed to
    resolve to the bot-produced recording, since this scenario dispatches
    exactly one bot session.
  """

  use EarWitnessSpex.Case

  spex "Bot recordings get transcripts and speakers automatically" do
    scenario "busy professional opens their bot's recording and it's already transcribed",
             context do
      given_ "a bot's completed meeting session has produced a recording in the library",
             context do
        {_view, _html, session_id} =
          EarWitnessSpex.BotSteps.dispatch_bot(context.conn, "https://zoom.us/j/5551234567")

        EarWitnessSpex.Fixtures.simulate_bot_join_completed(session_id)
        context
      end

      when_ "they open the bot's recording without taking any transcribe action", context do
        {:ok, recordings_view, recordings_html} = live(context.conn, "/recordings")
        [_, show_path] = Regex.run(~r{href="(/recordings/[^"]+)"}, recordings_html)
        {:ok, show_view, show_html} = live(context.conn, show_path)

        context
        |> Map.put(:recordings_view, recordings_view)
        |> Map.put(:show_view, show_view)
        |> Map.put(:show_html, show_html)
      end

      then_ "a transcript is already there, produced automatically rather than waiting for " <>
              "an explicit Transcribe action",
            context do
        assert has_element?(context.show_view, ~s([data-test="transcript"]))
        refute has_element?(context.show_view, ~s([data-test="transcribe-button"]))

        :ok
      end

      then_ "its segments already carry speaker attribution", context do
        assert has_element?(context.show_view, ~s([data-test="segment-speaker"]))

        :ok
      end
    end
  end
end
