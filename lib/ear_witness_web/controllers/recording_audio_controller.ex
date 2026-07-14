defmodule EarWitnessWeb.RecordingAudioController do
  @moduledoc """
  Streams a recording's audio file so the transcript editor's `<audio>` element
  can play it (and seek to a segment). `send_file/3` honors Range requests, so
  seeking to a segment's start streams only the needed bytes rather than the
  whole file.
  """
  use EarWitnessWeb, :controller

  alias EarWitness.Recordings

  def show(conn, %{"id" => id}) do
    with {:ok, recording} <- Recordings.get_recording(id),
         true <- File.exists?(recording.file_path) do
      conn
      |> put_resp_content_type("audio/wav")
      |> send_file(200, recording.file_path)
    else
      _ -> send_resp(conn, 404, "Recording audio not found")
    end
  end
end
