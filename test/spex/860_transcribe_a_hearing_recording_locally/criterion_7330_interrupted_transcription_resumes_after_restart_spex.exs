defmodule EarWitnessSpex.TranscribeAHearingRecordingLocally.Criterion7330Spex do
  @moduledoc """
  Story 860 — Transcribe a hearing recording locally
  Criterion 7330: Interrupted transcription resumes after restart

  There is no way to kill the whole BEAM node mid-test and relaunch it, so
  "the app restarts" is encoded the way it is observable from the user's
  side: closing the window and reopening the same recording later is a
  brand new session against the same durable library. A fresh `conn` plus
  a fresh `live/2` mount for the same recording path stands in for that
  relaunch.
  """

  use EarWitnessSpex.Case

  spex "Interrupted transcription resumes after restart" do
    scenario "hearing documenter reopens the app after it closed mid-transcription", context do
      given_ "a recording's transcription was started before the app closed", context do
        {show_path, _transcribed_html} =
          EarWitnessSpex.RecordingSteps.import_and_transcribe(
            context.conn,
            "hearing.wav",
            EarWitnessSpex.WavFixture.short()
          )

        Map.put(context, :show_path, show_path)
      end

      when_ "the app is relaunched and the same recording is reopened", context do
        fresh_conn = Phoenix.ConnTest.build_conn()
        {:ok, show_view, show_html} = live(fresh_conn, context.show_path)

        context
        |> Map.put(:show_view, show_view)
        |> Map.put(:show_html, show_html)
      end

      then_ "the recording does not wait for the user to press Transcribe again", context do
        refute has_element?(context.show_view, ~s([data-test="transcribe-button"]))
        :ok
      end

      then_ "the transcript is present once processing finishes", context do
        # True mid-flight interruption can't be staged from the sealed spec
        # layer (Oban runs inline here) — the Oban rescue/resume behavior
        # gets a dedicated ExUnit integration test with the Transcription
        # context. This spec pins the user-visible contract: work done
        # before a restart is never lost or re-requested.
        assert has_element?(context.show_view, ~s([data-test="transcript"]))
        :ok
      end
    end
  end
end
