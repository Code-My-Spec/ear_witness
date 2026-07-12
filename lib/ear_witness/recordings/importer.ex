defmodule EarWitness.Recordings.Importer do
  @moduledoc """
  Reads and structurally validates an externally-sourced audio file and
  places a copy under the recordings directory.

  Real 16kHz-mono resampling (DSP) is not wired up yet — no resampler
  dependency is part of this project (see the membrane-audio-capture ADR);
  only structural WAV validity is enforced today, and the file's own
  declared sample rate/duration is trusted and copied through unchanged.
  Revisit once a resampler lands; `EarWitness.Recordings.WavHeader` already
  gives every caller the honest declared duration regardless.
  """

  alias EarWitness.Recordings.WavHeader

  @spec import(Path.t(), String.t()) ::
          {:ok, %{file_path: Path.t(), duration: float()}} | {:error, :invalid_audio_file}
  def import(upload_path, original_filename) do
    with {:ok, bytes} <- File.read(upload_path),
         {:ok, header} <- WavHeader.parse(bytes) do
      dest = destination_path(original_filename)
      File.mkdir_p!(Path.dirname(dest))
      File.write!(dest, bytes)
      {:ok, %{file_path: dest, duration: header.duration_seconds}}
    else
      _ -> {:error, :invalid_audio_file}
    end
  end

  defp destination_path(original_filename) do
    ext =
      case Path.extname(original_filename) do
        "" -> ".wav"
        ext -> ext
      end

    Path.join(EarWitness.recordings_dir(), Ecto.UUID.generate() <> ext)
  end
end
