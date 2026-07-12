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

  @impl true
  def render(assigns) do
    ~H"""
    <div id={@id} class="card bg-base-100 shadow-sm">
      <div class="card-body">
        <h2 class="card-title">Speakers</h2>
        <div class="flex flex-col gap-3">
          <div :for={{speaker, index} <- Enum.with_index(@speakers)} class="flex items-center gap-2">
            <span data-test="speaker-chip" data-speaker-id={speaker.id} class="badge badge-primary">
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
              Forget
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
