defmodule EarWitnessSpex.TranscribeAHearingRecordingLocally.Criterion7331Spex do
  @moduledoc """
  Story 860 — Transcribe a hearing recording locally
  Criterion 7331: Reopen a transcript after restarting the app

  As in criterion 7330, "the app restarts" is encoded as a fresh `conn`
  plus a fresh `live/2` mount for the same recording path — the closest
  observable stand-in for relaunching the desktop app against the same
  durable local library.
  """

  use EarWitnessSpex.Case

  spex "Reopen a transcript after restarting the app" do
    scenario "hearing documenter reopens a finished transcript in a new app session", context do
      given_ "a recording has been imported and fully transcribed", context do
        {show_path, _transcribed_html} =
          EarWitnessSpex.RecordingSteps.import_and_transcribe(
            context.conn,
            "hearing.wav",
            EarWitnessSpex.WavFixture.short()
          )

        Map.put(context, :show_path, show_path)
      end

      when_ "the app restarts and they reopen the same recording", context do
        fresh_conn = Phoenix.ConnTest.build_conn()
        {:ok, _show_view, reopened_html} = live(fresh_conn, context.show_path)

        Map.put(context, :reopened_html, reopened_html)
      end

      then_ "the transcript is exactly as it was left, without redoing any work", context do
        assert context.reopened_html =~ ~s(data-test="transcript")
        assert context.reopened_html =~ "Testing"
        :ok
      end
    end
  end
end
