defmodule EarWitness.Transcription.LiveTranscriberTest do
  use ExUnit.Case, async: false

  alias EarWitness.Transcription.LiveTranscriber

  # The live de-dup rule (issue 0787506d): segments that straddle the last
  # committed boundary must be kept (clamped), not dropped whole.
  describe "commit_candidates/2" do
    test "keeps segments starting at or after the committed end" do
      candidates = [
        %{text: "new speech", start_offset: 20_000, end_offset: 23_000},
        %{text: "later speech", start_offset: 23_000, end_offset: 25_000}
      ]

      assert LiveTranscriber.commit_candidates(candidates, 20_000) == candidates
    end

    test "keeps a boundary-straddling segment, clamping its start to the boundary" do
      straddler = %{text: "spans the boundary", start_offset: 19_800, end_offset: 22_500}

      assert [%{text: "spans the boundary", start_offset: 20_000, end_offset: 22_500}] =
               LiveTranscriber.commit_candidates([straddler], 20_000)
    end

    test "drops carry re-hearings that start well before the boundary" do
      rehearing = %{text: "already committed", start_offset: 18_500, end_offset: 20_100}

      assert LiveTranscriber.commit_candidates([rehearing], 20_000) == []
    end

    test "drops segments fully inside the committed region and empty text" do
      candidates = [
        %{text: "old", start_offset: 19_600, end_offset: 19_900},
        %{text: "", start_offset: 21_000, end_offset: 22_000}
      ]

      assert LiveTranscriber.commit_candidates(candidates, 20_000) == []
    end
  end
end
