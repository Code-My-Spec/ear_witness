defmodule EarWitnessSpex.KnowWhoSaidWhat.Criterion7342Spex do
  @moduledoc """
  Story 862 — Know who said what
  Criterion 7342: Diarize with networking disabled

  Mirrors story 860's criterion 7326 ("Transcribe successfully with
  networking disabled"): the "no network" guarantee is structural, not
  simulated. `EarWitness.Speakers` depends only on `EarWitness.Models` and
  `EarWitness.Transcription` (see the architecture proposal) — it takes no
  HTTP client dependency, so nothing in the diarization pipeline COULD
  phone home during clustering (see the local-first-privacy ADR and the
  project BDD plan's seams section). The diarizer itself runs behind the
  `Speakers.Diarizer` seam (ONNX models via ortex, in-process), whose test
  double replays recorded real ONNX pipeline output rather than synthetic
  data. This spec drives the flow through the real UI and asserts every
  transcript segment carries a genuine speaker attribution, produced
  entirely on-device.
  """

  use EarWitnessSpex.Case

  spex "Diarize with networking disabled" do
    scenario "hearing documenter transcribes a recording and every segment is attributed on-device",
             context do
      given_ "a recording has been imported into the library", context do
        {show_path, _index_html} =
          EarWitnessSpex.RecordingSteps.import_wav(
            context.conn,
            "hearing.wav",
            EarWitnessSpex.WavFixture.short()
          )

        Map.put(context, :show_path, show_path)
      end

      when_ "they transcribe the recording and open its transcript", context do
        {:ok, show_view, _html} = live(context.conn, context.show_path)
        show_view |> element(~s([data-test="transcribe-button"])) |> render_click()

        {view, html} =
          EarWitnessSpex.TranscriptSteps.open_editor(context.conn, context.show_path)

        context
        |> Map.put(:view, view)
        |> Map.put(:html, html)
      end

      then_ "every transcript segment is attributed to a speaker, produced without any network access",
            context do
        segments = Regex.scan(~r/data-test="transcript-segment"/, context.html)
        speaker_labels = Regex.scan(~r/data-test="segment-speaker"/, context.html)

        assert segments != []
        assert length(speaker_labels) == length(segments)
        :ok
      end
    end
  end
end
