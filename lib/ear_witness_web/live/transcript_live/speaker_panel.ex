defmodule EarWitnessWeb.TranscriptLive.SpeakerPanel do
  @moduledoc """
  Name, merge, and recolor the speakers detected in a recording.

  Purely presentational: every control here fires straight up to the
  parent `EarWitnessWeb.TranscriptLive.Editor` (no `phx-target`), which
  owns the transcript's segments and speakers and re-renders this panel
  with fresh assigns after handling the event.
  """

  use EarWitnessWeb, :live_component

  alias EarWitness.Speakers

  # Cycles a small, readable palette across speakers by index so each one
  # reads as a consistent color both here and against their segments in
  # the transcript — same idea as chat-app participant colors.
  @chip_colors ~w(badge-primary badge-secondary badge-accent badge-info badge-warning)

  @impl true
  def render(assigns) do
    ~H"""
    <div id={@id} class="card bg-base-100 border border-base-300 shadow-sm">
      <div class="card-body">
        <h2 class="card-title">
          <.icon name="hero-user-group" class="size-5 text-primary" /> Speakers
        </h2>
        <div class="flex flex-col gap-3">
          <div :for={{speaker, index} <- Enum.with_index(@speakers)} class="flex flex-wrap items-center gap-2">
            <%!--
              Several `_spex.exs` scans (story 862) read a speaker's id and
              label off this exact tag with
              `data-test="speaker-chip" data-speaker-id="..."` immediately
              adjacent, then take the tag's OWN bare text as the label — so
              nothing may wrap `Speakers.label/2` inside this span, and no
              attribute may be inserted between `data-test` and
              `data-speaker-id`.
            --%>
            <span
              data-test="speaker-chip"
              data-speaker-id={speaker.id}
              class={["badge", chip_color(index)]}
            >
              {Speakers.label(speaker, index)}
            </span>

            <form
              id={"speaker-name-form-#{speaker.id}"}
              data-test="speaker-name-form"
              data-speaker-id={speaker.id}
              phx-submit="rename_speaker"
              phx-value-id={speaker.id}
              class="flex items-center gap-1"
            >
              <input
                type="text"
                name="name"
                value={speaker.name}
                placeholder={Speakers.label(speaker, index)}
                class="input input-bordered input-sm"
              />
              <button type="submit" class="btn btn-sm">Rename</button>
            </form>

            <button
              type="button"
              data-test="delete-voice-signature"
              data-speaker-name={Speakers.label(speaker, index)}
              phx-click="forget_speaker"
              phx-value-id={speaker.id}
              class="btn btn-sm btn-ghost"
            >
              <.icon name="hero-trash" class="size-3.5" /> Forget
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp chip_color(index), do: Enum.at(@chip_colors, rem(index, length(@chip_colors)))
end
