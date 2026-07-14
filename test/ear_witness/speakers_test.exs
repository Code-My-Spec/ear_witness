defmodule EarWitness.SpeakersTest do
  use EarWitnessTest.DataCase, async: false

  alias EarWitness.Recordings
  alias EarWitness.Speakers
  alias EarWitness.Transcription

  describe "diarize_transcript/1 during live capture" do
    test "skips an in-progress transcript without marking it diarized" do
      {:ok, recording} =
        Recordings.create_recording(%{
          title: "live-capture.wav",
          source: :captured,
          capture_source: :microphone,
          file_path: "/nonexistent/live-capture.wav",
          duration: 0.0
        })

      {:ok, transcript} = Transcription.create_live_transcript(recording.id)
      assert transcript.status == :transcribing

      assert :ok = Speakers.diarize_transcript(transcript)

      # Untouched: segmentation/clustering must wait for the recording to
      # finish, and diarized_at must stay nil so the post-stop pass still runs.
      {:ok, reloaded} = Transcription.get_transcript_for_recording(recording.id)
      assert reloaded.diarized_at == nil
    end
  end
end
