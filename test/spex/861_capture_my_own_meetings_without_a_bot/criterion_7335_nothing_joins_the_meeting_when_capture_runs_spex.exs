defmodule EarWitnessSpex.CaptureMyOwnMeetingsWithoutABot.Criterion7335Spex do
  @moduledoc """
  Story 861 — Capture my own meetings without a bot
  Criterion 7335: Nothing joins the meeting when capture runs

  The guarantee is structural: tap capture reads local audio devices and
  has no meeting-join capability at all — joining meetings exists only in
  the separate Bots context (story 869), which the capture path never
  touches. The observable from inside the app: running a tap capture
  creates no bot session. (No spec can assert on a third-party meeting's
  participant list; the absence of any join mechanism is the proof, and
  this spec pins the closest in-app observable.)
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

      then_ "no bot session was ever created", context do
        {:ok, bots_view, _html} = live(context.conn, "/bots")
        refute has_element?(bots_view, ~s([data-test="bot-session"]))
        :ok
      end
    end
  end
end
