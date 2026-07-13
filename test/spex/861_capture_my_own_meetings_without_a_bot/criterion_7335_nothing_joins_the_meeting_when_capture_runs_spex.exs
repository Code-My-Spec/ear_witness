defmodule EarWitnessSpex.CaptureMyOwnMeetingsWithoutABot.Criterion7335Spex do
  @moduledoc """
  Story 861 — Capture my own meetings without a bot
  Criterion 7335: Nothing joins the meeting when capture runs

  The guarantee is structural: tap capture reads local audio devices and
  has no meeting-join capability at all. The meeting-bot feature (the only
  thing that could ever join a meeting) was removed from the app entirely,
  so the absence is now absolute — there is no join mechanism to invoke.
  The observable from inside the app: capture produces a local recording,
  and there is no meeting-join surface to reach at all. (No spec can assert
  on a third-party meeting's participant list; the absence of any join
  mechanism is the proof, and this spec pins the closest in-app observable.)
  """

  use EarWitnessSpex.Case

  spex "Nothing joins the meeting when capture runs" do
    scenario "meeting participant captures a full meeting via the tap", context do
      given_ "the tap is the active capture source", context do
        EarWitnessSpex.SettingsSteps.choose_tap_capture_source(context.conn)
        {:ok, view, _html} = live(context.conn, "/recordings")
        Map.put(context, :view, view)
      end

      when_ "capture runs for the whole meeting", context do
        context.view |> element("button", "Record") |> render_click()
        context.view |> element("button", "Stop") |> render_click()
        context
      end

      then_ "the capture produced a recording", context do
        assert has_element?(context.view, ~s([data-test="recording-row"]))
        :ok
      end

      then_ "the app exposes no meeting-join surface at all", context do
        # The meeting-bot feature was removed, so there is structurally no
        # route to any join mechanism — the /bots surface returns 404.
        assert get(context.conn, "/bots").status == 404
        :ok
      end
    end
  end
end
