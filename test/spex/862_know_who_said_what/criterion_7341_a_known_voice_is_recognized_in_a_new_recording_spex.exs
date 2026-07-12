defmodule EarWitnessSpex.KnowWhoSaidWhat.Criterion7341Spex do
  @moduledoc """
  Story 862 — Know who said what
  Criterion 7341: A known voice is recognized in a new recording

  The precondition — "a known speaker with a stored voice signature
  already exists" (from a prior recording) — cannot be staged honestly
  through the real UI yet: it requires the `Speakers.Diarizer` and
  `Speakers.Identifier` seams (clustering + cross-recording matching),
  neither of which exists. Per the project's honest-stub convention (see
  `EarWitnessSpex.Fixtures.simulate_no_input_devices/0` and friends), this
  spec uses `EarWitnessSpex.Fixtures.simulate_known_speaker_with_voice_signature/1`
  — which raises "not implemented yet" — rather than faking the speaker
  into existence. That keeps this spec honestly red at the very first
  step; the `when_`/`then_` steps below are written as the criterion would
  actually be exercised once the seam lands, driving the real transcribe
  flow and reading the real `SpeakerPanel`/segment output.
  """

  use EarWitnessSpex.Case

  spex "A known voice is recognized in a new recording" do
    scenario "hearing documenter transcribes a new recording featuring an already-known voice",
             context do
      given_ "a known speaker with a stored voice signature already exists", context do
        EarWitnessSpex.Fixtures.simulate_known_speaker_with_voice_signature("Alex")
        context
      end

      when_ "a new recording featuring that same voice is imported and transcribed", context do
        {show_path, _transcribed_html} =
          EarWitnessSpex.RecordingSteps.import_and_transcribe(
            context.conn,
            "second-meeting-with-alex.wav",
            EarWitnessSpex.WavFixture.short()
          )

        {view, html} = EarWitnessSpex.TranscriptSteps.open_editor(context.conn, show_path)

        context
        |> Map.put(:view, view)
        |> Map.put(:html, html)
      end

      then_ "the segments spoken by that voice are attributed to the already-known speaker without any manual naming",
            context do
        assert has_element?(context.view, ~s([data-test="segment-speaker"]), "Alex")
        :ok
      end
    end
  end
end
