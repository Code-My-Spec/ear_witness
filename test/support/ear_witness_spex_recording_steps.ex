defmodule EarWitnessSpex.RecordingSteps do
  @moduledoc """
  Reusable steps for driving `EarWitnessWeb.RecordingLive.Index` and
  `EarWitnessWeb.RecordingLive.Show` from BDD specs.

  Plain helper functions, not macros — the installed `sexy_spex` version
  (`~> 0.1.0`) has no shared-given registration mechanism (no
  `register_given`/`import_givens`), so specs call these directly from
  inside `given_`/`when_`/`then_` blocks. Every call here still goes
  through the real LiveView surface — nothing here reaches into
  `EarWitness.*` contexts, `Repo`, `File`, or `Port` (see the local Credo
  check `EARWIT0001`).
  """

  @endpoint EarWitnessWeb.Endpoint

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  @doc """
  Opens the recordings library, imports the given WAV bytes under
  `filename`, and returns `{show_path, index_html}` — the new recording's
  `/recordings/:id` path (read off the rendered library HTML) and the
  library's rendered HTML right after the import.
  """
  def import_wav(conn, filename, wav_bytes) do
    {:ok, index_view, _html} = live(conn, "/recordings")

    upload =
      file_input(index_view, "#import-form", :audio_file, [
        %{
          name: filename,
          content: wav_bytes,
          size: byte_size(wav_bytes),
          type: "audio/wav"
        }
      ])

    render_upload(upload, filename)
    index_html = index_view |> form("#import-form") |> render_submit()
    [_, show_path] = Regex.run(~r{href="(/recordings/[^"]+)"}, index_html)

    {show_path, index_html}
  end

  @doc """
  Imports the given WAV bytes and immediately triggers transcription on
  the resulting recording. Returns `{show_path, transcribed_html}`.
  """
  def import_and_transcribe(conn, filename, wav_bytes) do
    {show_path, _index_html} = import_wav(conn, filename, wav_bytes)
    {:ok, show_view, _html} = live(conn, show_path)

    transcribed_html =
      show_view |> element(~s([data-test="transcribe-button"])) |> render_click()

    {show_path, transcribed_html}
  end
end
