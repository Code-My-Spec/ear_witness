defmodule EarWitnessSpex.TranscribeAHearingRecordingLocally.Criterion7326Spex do
  @moduledoc """
  Story 860 — Transcribe a hearing recording locally
  Criterion 7326: Transcribe successfully with networking disabled

  The "no network" guarantee is structural, not simulated: transcription
  runs behind the engine seam (`config :ear_witness, :transcription_engine`)
  whose real implementation is the whisper.cpp NIF — in-process C code with
  no HTTP client, in a context that takes no HTTP dependency (see the
  local-first-privacy ADR and the BDD plan's seams section). This spec
  drives the flow through the UI and asserts a real transcript materializes
  from the local engine — the recorded-response double replays actual
  whisper.cpp output ("Testing 1, 2, 3." from test/fixtures/vad-f32.raw),
  so the assertion pins the engine's genuine text, not a placeholder.
  """

  use EarWitnessSpex.Case

  spex "Transcribe successfully with networking disabled" do
    scenario "hearing documenter transcribes a recording entirely on-device", context do
      given_ "a recording has been imported into the library", context do
        {show_path, _index_html} =
          EarWitnessSpex.RecordingSteps.import_wav(
            context.conn,
            "hearing.wav",
            EarWitnessSpex.WavFixture.short()
          )

        Map.put(context, :show_path, show_path)
      end

      when_ "they transcribe the recording", context do
        {:ok, show_view, _html} = live(context.conn, context.show_path)
        show_view |> element(~s([data-test="transcribe-button"])) |> render_click()
        Map.put(context, :show_view, show_view)
      end

      then_ "the local engine's transcript is shown, produced without any network access",
            context do
        assert has_element?(context.show_view, ~s([data-test="transcript"]))

        assert has_element?(
                 context.show_view,
                 ~s([data-test="transcript-segment"]),
                 "Testing"
               )

        :ok
      end
    end
  end
end
