defmodule EarWitnessSpex.TranscribeAHearingRecordingLocally.Criterion7323Spex do
  @moduledoc """
  Story 860 — Transcribe a hearing recording locally
  Criterion 7323: Reject a corrupt or unsupported file without touching the library
  """

  use EarWitnessSpex.Case

  spex "Reject a corrupt or unsupported file without touching the library" do
    scenario "hearing documenter tries to import a file that is not a usable recording",
             context do
      given_ "the recordings library already has one recording in it", context do
        {_path, _index_html} =
          EarWitnessSpex.RecordingSteps.import_wav(
            context.conn,
            "existing-hearing.wav",
            EarWitnessSpex.WavFixture.short()
          )

        {:ok, view, _reload_html} = live(context.conn, "/recordings")
        Map.put(context, :view, view)
      end

      when_ "they attempt to import a corrupt file", context do
        corrupt = EarWitnessSpex.WavFixture.corrupt()

        upload =
          file_input(context.view, "#import-form", :audio_file, [
            %{
              name: "broken-recording.wav",
              content: corrupt,
              size: byte_size(corrupt),
              type: "audio/wav"
            }
          ])

        render_upload(upload, "broken-recording.wav")

        html =
          context.view
          |> form("#import-form")
          |> render_submit()

        Map.put(context, :html, html)
      end

      then_ "they see an error explaining the file could not be imported", context do
        assert has_element?(context.view, ~s([data-test="import-error"]))
        :ok
      end

      then_ "the library still shows only the recording that was already there", context do
        refute has_element?(
                 context.view,
                 ~s([data-test="recording-row"]),
                 "broken-recording.wav"
               )

        assert has_element?(
                 context.view,
                 ~s([data-test="recording-row"]),
                 "existing-hearing.wav"
               )

        :ok
      end
    end
  end
end
