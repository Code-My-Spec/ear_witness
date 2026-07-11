defmodule EarWitnessSpex.TranscribeAHearingRecordingLocally.Criterion7332Spex do
  @moduledoc """
  Story 860 — Transcribe a hearing recording locally
  Criterion 7332: Imported recording waits for an explicit transcribe action
  """

  use EarWitnessSpex.Case

  spex "Imported recording waits for an explicit transcribe action" do
    scenario "hearing documenter imports a recording and it does not transcribe itself",
             context do
      given_ "a recording has just been imported into the library", context do
        {show_path, _index_html} =
          EarWitnessSpex.RecordingSteps.import_wav(
            context.conn,
            "hearing.wav",
            EarWitnessSpex.WavFixture.short()
          )

        Map.put(context, :show_path, show_path)
      end

      when_ "they open the recording without clicking transcribe", context do
        {:ok, show_view, show_html} = live(context.conn, context.show_path)

        context
        |> Map.put(:show_view, show_view)
        |> Map.put(:show_html, show_html)
      end

      then_ "the recording is waiting, not already transcribed", context do
        refute context.show_html =~ ~s(data-test="transcript")
        :ok
      end

      then_ "an explicit Transcribe action is available for them to take", context do
        assert has_element?(context.show_view, ~s([data-test="transcribe-button"]))
        :ok
      end
    end
  end
end
