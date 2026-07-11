defmodule EarWitnessSpex.TranscribeAHearingRecordingLocally.Criterion7329Spex do
  @moduledoc """
  Story 860 — Transcribe a hearing recording locally
  Criterion 7329: Keep using the app while transcription runs

  Each mounted LiveView test view is its own process, so starting
  transcription on one recording (via `Task.async/1`, so the test process
  doesn't wait on it) while immediately opening a second recording proves
  the rest of the app stays usable — the second mount doesn't queue behind
  the first.
  """

  use EarWitnessSpex.Case

  spex "Keep using the app while transcription runs" do
    scenario "hearing documenter keeps browsing the library while one recording transcribes",
             context do
      given_ "two recordings have been imported into the library", context do
        {first_path, _first_html} =
          EarWitnessSpex.RecordingSteps.import_wav(
            context.conn,
            "first-hearing.wav",
            EarWitnessSpex.WavFixture.short()
          )

        {second_path, _second_html} =
          EarWitnessSpex.RecordingSteps.import_wav(
            context.conn,
            "second-hearing.wav",
            EarWitnessSpex.WavFixture.short()
          )

        context
        |> Map.put(:first_path, first_path)
        |> Map.put(:second_path, second_path)
      end

      when_ "they start transcribing the first recording and immediately open the second",
            context do
        {:ok, first_view, _html} = live(context.conn, context.first_path)

        transcribe_task =
          Task.async(fn ->
            first_view |> element(~s([data-test="transcribe-button"])) |> render_click()
          end)

        {:ok, _second_view, second_html} = live(context.conn, context.second_path)

        transcribe_html = Task.await(transcribe_task, 30_000)

        context
        |> Map.put(:second_html, second_html)
        |> Map.put(:transcribe_html, transcribe_html)
      end

      then_ "the second recording's page loads and is fully usable", context do
        assert context.second_html =~ "second-hearing.wav"
        :ok
      end

      then_ "the first recording still finishes transcribing in the background", context do
        assert context.transcribe_html =~ ~s(data-test="transcript")
        :ok
      end
    end
  end
end
