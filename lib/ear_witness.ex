defmodule EarWitness do
  @moduledoc """
    Top-level module for the EarWitness domain. Holds the well-known
    filesystem locations used by the application (config, recordings,
    transcripts, bundled binaries).
  """

  def config_dir(), do: Path.join([Desktop.OS.home(), ".config", "discussit"])
  def app_dir(), do: Path.join([Desktop.OS.home(), "Documents", "Discussit"])
  def recordings_dir(), do: Path.join(app_dir(), "recordings")
  def binaries_dir(), do: Path.join([:code.priv_dir(:ear_witness), "binaries"])
  def transcription_id(), do: Path.join(app_dir(), "transcripts")
end
