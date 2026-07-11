defmodule EarWitness do
  @moduledoc """
    Top-level module for the EarWitness domain. Holds the well-known
    filesystem locations used by the application (config, recordings,
    transcripts, bundled binaries).
  """

  # Mass-exported: the context sub-boundaries described in the architecture
  # proposal (Recordings, Transcription, Speakers, ...) don't exist in code
  # yet, so a curated export list would be guesswork. This groups all
  # existing EarWitness.* modules under one classified boundary without
  # inventing premature per-module restrictions; narrow the exports once
  # the real contexts land (see architecture proposal).
  #
  # dirty_xrefs: MenuBar is leftover elixir_desktop Todo-app scaffold that
  # reaches into the web layer (open-browser, notification callback) —
  # pre-existing behavior, not something to refactor here.
  use Boundary,
    deps: [],
    exports: :all,
    dirty_xrefs: [EarWitnessWeb.Endpoint, EarWitnessWeb.TodoLive]

  def config_dir(), do: Path.join([Desktop.OS.home(), ".config", "discussit"])
  def app_dir(), do: Path.join([Desktop.OS.home(), "Documents", "Discussit"])
  def recordings_dir(), do: Path.join(app_dir(), "recordings")
  def binaries_dir(), do: Path.join([:code.priv_dir(:ear_witness), "binaries"])
  def transcription_id(), do: Path.join(app_dir(), "transcripts")
end
