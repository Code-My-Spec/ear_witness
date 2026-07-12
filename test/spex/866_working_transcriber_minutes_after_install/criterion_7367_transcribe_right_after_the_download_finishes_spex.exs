defmodule EarWitnessSpex.WorkingTranscriberMinutesAfterInstall.Criterion7367Spex do
  @moduledoc """
  Story 866 — Working transcriber minutes after install
  Criterion 7367: Transcribe right after the download finishes

  Chains the real setup flow into the real transcribe flow
  (`EarWitnessSpex.RecordingSteps.import_and_transcribe/3`, the same
  helper story 860's specs use) to pin the story's actual promise: a
  working transcriber "minutes after install," not just a model file on
  disk.

  Judgment call made explicit: the setup flow is assumed to end by
  landing the user somewhere they can immediately import/record — this
  spec navigates to `/recordings` directly after the download completes
  rather than asserting on whatever exact hand-off UI setup ends with.
  """

  use EarWitnessSpex.Case

  spex "Transcribe right after the download finishes" do
    scenario "new user transcribes their first recording immediately after setup finishes",
             context do
      given_ "the model download has just finished during first-run setup", context do
        {view, _html} = EarWitnessSpex.SetupSteps.open_setup(context.conn)
        EarWitnessSpex.SetupSteps.start_download(view)
        context
      end

      when_ "they import and transcribe their first recording", context do
        {show_path, transcribed_html} =
          EarWitnessSpex.RecordingSteps.import_and_transcribe(
            context.conn,
            "first-hearing.wav",
            EarWitnessSpex.WavFixture.short()
          )

        context
        |> Map.put(:show_path, show_path)
        |> Map.put(:transcribed_html, transcribed_html)
      end

      then_ "a working transcript is produced, with no manual model setup required", context do
        assert context.transcribed_html =~ ~s(data-test="transcript")
        :ok
      end
    end
  end
end
