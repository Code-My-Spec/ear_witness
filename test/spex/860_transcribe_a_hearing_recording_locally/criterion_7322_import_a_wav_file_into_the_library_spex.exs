defmodule EarWitnessSpex.TranscribeAHearingRecordingLocally.Criterion7322Spex do
  @moduledoc """
  Story 860 — Transcribe a hearing recording locally
  Criterion 7322: Import a WAV file into the library
  """

  use EarWitnessSpex.Case

  spex "Import a WAV file into the library" do
    scenario "hearing documenter imports a WAV recording of a public proceeding", context do
      given_ "the recordings library is open", context do
        {:ok, view, _html} = live(context.conn, "/recordings")
        Map.put(context, :view, view)
      end

      when_ "they import a WAV file of the hearing", context do
        wav = EarWitnessSpex.WavFixture.short()

        upload =
          file_input(context.view, "#import-form", :audio_file, [
            %{
              name: "tenant-board-hearing.wav",
              content: wav,
              size: byte_size(wav),
              type: "audio/wav"
            }
          ])

        render_upload(upload, "tenant-board-hearing.wav")

        html =
          context.view
          |> form("#import-form")
          |> render_submit()

        Map.put(context, :html, html)
      end

      then_ "the recording appears in the library with its title and duration", context do
        assert has_element?(
                 context.view,
                 ~s([data-test="recording-row"]),
                 "tenant-board-hearing.wav"
               )

        assert has_element?(context.view, ~s([data-test="recording-duration"]))
        :ok
      end
    end
  end
end
