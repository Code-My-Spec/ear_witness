defmodule EarWitnessSpex.TranscriptSteps do
  @moduledoc """
  Reusable steps for driving `EarWitnessWeb.TranscriptLive.Editor` (and its
  `SpeakerPanel` component) from BDD specs.

  Plain helper functions, not macros — the installed `sexy_spex` version
  (`~> 0.1.0`) has no shared-given registration mechanism (no
  `register_given`/`import_givens`), so specs call these directly from
  inside `given_`/`when_`/`then_` blocks — see
  `EarWitnessSpex.RecordingSteps` for the same rationale. Every call here
  still goes through the real LiveView surface — nothing here reaches into
  `EarWitness.*` contexts, `Repo`, `File`, or `Port` (see the local Credo
  check `EARWIT0001`).

  ## Route assumption

  Neither `EarWitnessWeb.TranscriptLive.Editor` nor its route exists yet
  (story 862). This helper assumes the editor is reachable at
  `<recording show_path>/transcript` — nested under the recording it
  belongs to, mirroring `EarWitnessWeb.RecordingLive.Show`'s
  `/recordings/:id`. That's a judgment call made explicit here so a human
  can correct it (and this one helper) before implementation if the real
  route differs; every story 862/863 spec goes through this function
  rather than hard-coding the path itself.
  """

  @endpoint EarWitnessWeb.Endpoint

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  @doc """
  Opens the transcript editor for the recording at `show_path` (as
  returned by `EarWitnessSpex.RecordingSteps.import_wav/3` or
  `import_and_transcribe/3`). Returns `{view, html}`.
  """
  def open_editor(conn, show_path) do
    {:ok, view, html} = live(conn, show_path <> "/transcript")
    {view, html}
  end

  @doc """
  Finds the `data-segment-id` of the transcript segment whose rendered
  text contains `text_fragment`, by scanning `html` for
  `[data-test="transcript-segment"]` elements. Mirrors how
  `EarWitnessSpex.KnowWhoSaidWhat.Criterion7340Spex` extracts a
  `data-speaker-id` from `[data-test="speaker-chip"]`.

  Judgment call made explicit (story 863): assumes each transcript
  segment container carries its own `data-segment-id` attribute, in
  `data-test="transcript-segment" data-segment-id="..."` order, and that
  the segment's text is the element's own text content — flag for a
  human to confirm before implementation.
  """
  def segment_id(html, text_fragment) do
    ~r/data-test="transcript-segment" data-segment-id="([^"]+)"[^>]*>([^<]*)</
    |> Regex.scan(html)
    |> Enum.find(fn [_, _id, text] -> String.contains?(text, text_fragment) end)
    |> then(fn [_, id, _text] -> id end)
  end

  @doc """
  Corrects a segment's transcript text through its inline editor input
  (`[data-test="segment-editor"][data-segment-id="..."]`, story 863
  criterion 7345), which saves on blur — no Save button. Returns the
  rendered HTML after the edit.
  """
  def edit_segment_text(view, segment_id, corrected_text) do
    view
    |> element(~s([data-test="segment-editor"][data-segment-id="#{segment_id}"]))
    |> render_blur(%{"value" => corrected_text})
  end

  @doc """
  Reassigns the segment identified by `segment_id` to the speaker
  identified by `speaker_id`, through its speaker-reassignment form
  (`[data-test="segment-speaker-form"][data-segment-id="..."]`, story 863
  criterion 7346 — distinct from `speaker-name-form`, which renames a
  speaker everywhere rather than moving one segment). Returns the
  rendered HTML after the change.
  """
  def reassign_segment_speaker(view, segment_id, speaker_name) do
    # The editor's per-segment speaker control is a type-to-create field: typing
    # an existing speaker's label reassigns to them; a new name creates a
    # speaker. Submitting the name is how a segment is (re)attributed.
    view
    |> form(~s([data-test="segment-speaker-form"][data-segment-id="#{segment_id}"]), %{
      "speaker_name" => speaker_name
    })
    |> render_submit()
  end

  @doc """
  Clicks the transcript segment identified by `segment_id` to start (or
  move) playback there (story 863 criteria 7347, 7351). Returns the
  rendered HTML after the click.
  """
  def click_segment(view, segment_id) do
    view
    |> element(~s([data-test="transcript-segment"][data-segment-id="#{segment_id}"]))
    |> render_click()
  end

  @doc """
  Clicks the editor's single, transcript-wide undo control
  (`[data-test="undo-button"]`, story 863 criterion 7349). Returns the
  rendered HTML after the click.
  """
  def click_undo(view) do
    view |> element(~s([data-test="undo-button"])) |> render_click()
  end

  @doc """
  Clicks the revert control for the segment identified by `segment_id`,
  restoring its text to what the transcription engine originally
  produced (`[data-test="revert-button"][data-segment-id="..."]`, story
  863 criterion 7350). Returns the rendered HTML after the click.
  """
  def click_revert(view, segment_id) do
    view
    |> element(~s([data-test="revert-button"][data-segment-id="#{segment_id}"]))
    |> render_click()
  end
end
