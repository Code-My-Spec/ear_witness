defmodule EarWitnessSpex.Fixtures do
  @moduledoc """
  Curated bridge from BDD specs into in-app state.

  The only module that may dep on `EarWitness` from inside the spex test
  tree. Declared as its own top-level Boundary so the spec boundary can dep
  on it without inheriting `EarWitness`'s deps.
  """

  use Boundary, top_level?: true, deps: [EarWitness]

  # --- Add re-exports below as specs need them. Keep the list small; every
  # export here is a sanctioned shortcut past the UI. ---
  #
  # Planned (uncomment as the contexts land — see architecture proposal):
  #
  #   defdelegate recording_fixture(attrs \\ %{}), to: EarWitness.Recordings
  #     # a completed recording on disk + Recording row, so transcript specs
  #     # don't have to drive a live capture first
  #
  #   defdelegate transcript_fixture(recording, attrs \\ %{}),
  #     to: EarWitness.Transcription
  #     # a finished transcript, so search/read specs skip the whisper run
end
