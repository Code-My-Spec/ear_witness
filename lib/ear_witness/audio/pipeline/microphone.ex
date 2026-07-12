defmodule EarWitness.Audio.Pipeline.Microphone do
  @moduledoc """
  Real (non-fixture) microphone-only capture pipeline — records the given
  input device straight to a file.
  """

  use Membrane.Pipeline

  @impl true
  def handle_init(_ctx, opts) do
    spec =
      child(:source, %Membrane.PortAudio.Source{
        device_id: opts[:device_id],
        sample_rate: 16_000,
        sample_format: :f32le,
        channels: 1
      })
      |> child(:sink, %Membrane.File.Sink{location: opts[:path]})

    {[spec: spec], %{}}
  end
end
