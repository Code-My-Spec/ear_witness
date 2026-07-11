defmodule EarWitnessSpex.TranscribeAHearingRecordingLocally.Criterion7327Spex do
  @moduledoc """
  Story 860 — Transcribe a hearing recording locally
  Criterion 7327: Transcribe a three-hour hearing block

  Uses `EarWitnessSpex.WavFixture.three_hours/0` — a WAV file whose header
  honestly declares a three-hour duration via a deliberately low sample
  rate, so the fixture stays tiny. The transcription engine itself runs
  behind a canned test double at the config seam (see
  `.code_my_spec/knowledge/bdd/spex/index.md`), so this scenario is about
  the library and transcription flow handling a long recording end to
  end, not about real multi-hour audio content.
  """

  use EarWitnessSpex.Case

  spex "Transcribe a three-hour hearing block" do
    scenario "hearing documenter transcribes a full three-hour hearing recording", context do
      given_ "a three-hour hearing recording has been imported", context do
        {show_path, _index_html} =
          EarWitnessSpex.RecordingSteps.import_wav(
            context.conn,
            "full-hearing-block.wav",
            EarWitnessSpex.WavFixture.three_hours()
          )

        Map.put(context, :show_path, show_path)
      end

      when_ "they open the recording and start transcription", context do
        {:ok, show_view, show_html} = live(context.conn, context.show_path)
        transcribe_html = show_view |> element("button", "Transcribe") |> render_click()

        context
        |> Map.put(:show_html, show_html)
        |> Map.put(:transcribe_html, transcribe_html)
      end

      then_ "the library shows its full three-hour duration", context do
        assert context.show_html =~ ~s(data-test="recording-duration")
        assert context.show_html =~ "3:00:00"
        :ok
      end

      then_ "the transcript for the entire three-hour block is produced", context do
        assert context.transcribe_html =~ ~s(data-test="transcript")
        :ok
      end
    end
  end
end
