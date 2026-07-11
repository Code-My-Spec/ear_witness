defmodule EarWitnessSpex.TranscribeAHearingRecordingLocally.Criterion7324Spex do
  @moduledoc """
  Story 860 — Transcribe a hearing recording locally
  Criterion 7324: Record live audio and land it in the library

  Capture runs behind the `config :ear_witness, :capture_source` seam —
  test env uses `:fixture`, which feeds fixture WAV bytes instead of a
  real portaudio device (see the BDD plan's seams section). The spec still
  drives the real Record/Stop UI; only the hardware edge is substituted.
  """

  use EarWitnessSpex.Case

  spex "Record live audio and land it in the library" do
    scenario "hearing documenter records the proceeding live instead of importing a file",
             context do
      given_ "the recordings library is open", context do
        {:ok, view, _html} = live(context.conn, "/recordings")
        Map.put(context, :view, view)
      end

      when_ "they start and then stop a live recording", context do
        context.view |> element("button", "Record") |> render_click()
        html = context.view |> element("button", "Stop") |> render_click()
        Map.put(context, :html, html)
      end

      then_ "the captured audio lands in the library as a new recording", context do
        assert has_element?(context.view, ~s([data-test="recording-row"]))

        assert has_element?(
                 context.view,
                 ~s([data-test="recording-source"]),
                 "captured"
               )

        :ok
      end
    end
  end
end
