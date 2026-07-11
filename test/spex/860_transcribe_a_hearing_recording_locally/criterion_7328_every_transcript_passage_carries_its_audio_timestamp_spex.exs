defmodule EarWitnessSpex.TranscribeAHearingRecordingLocally.Criterion7328Spex do
  @moduledoc """
  Story 860 — Transcribe a hearing recording locally
  Criterion 7328: Every transcript passage carries its audio timestamp
  """

  use EarWitnessSpex.Case

  spex "Every transcript passage carries its audio timestamp" do
    scenario "hearing documenter reads a finished transcript and sees timestamps throughout",
             context do
      given_ "a recording has been imported and transcribed", context do
        {show_path, _transcribed_html} =
          EarWitnessSpex.RecordingSteps.import_and_transcribe(
            context.conn,
            "hearing.wav",
            EarWitnessSpex.WavFixture.short()
          )

        Map.put(context, :show_path, show_path)
      end

      when_ "they view the finished transcript", context do
        {:ok, _show_view, html} = live(context.conn, context.show_path)
        Map.put(context, :html, html)
      end

      then_ "every transcript passage is shown with its own audio timestamp", context do
        segments = Regex.scan(~r/data-test="transcript-segment"/, context.html)
        stamps = Regex.scan(~r/data-test="segment-timestamp"/, context.html)

        assert segments != []
        assert length(stamps) == length(segments)
        :ok
      end
    end
  end
end
