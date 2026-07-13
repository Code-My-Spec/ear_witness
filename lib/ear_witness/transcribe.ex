defmodule EarWitness.Transcribe do
  @on_load :init

  def init do
    path = :filename.join(:code.priv_dir(:ear_witness), ~c"nif")
    # Tolerate a missing NIF so the module (and app) still load on platforms
    # where the whisper NIF isn't built yet (e.g. Windows). transcribe_files/2
    # then exits with :nif_library_not_loaded only if transcription is invoked.
    case :erlang.load_nif(path, 0) do
      :ok -> :ok
      {:error, _} -> :ok
    end
  end

  def transcribe_files(_file_paths, _model_path) do
    exit(:nif_library_not_loaded)
  end
end
