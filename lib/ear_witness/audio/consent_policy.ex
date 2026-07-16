defmodule EarWitness.Audio.ConsentPolicy do
  @moduledoc """
  Authorizes capture under the active recording consent/notification
  policy. `:silent` authorizes unconditionally; `:notify` authorizes and
  flags that the UI should show a notice; `:announce` plays an audible
  recording notice onto the user's outgoing voice channel (the
  `EarWitness.Audio.VirtualMic` seam) and only authorizes once that
  delivery succeeds — a failed or impossible delivery refuses capture
  (`{:error, :notice_undelivered}`), so no recording ever starts without
  the announcement participants are meant to hear.

  Delivery goes through `EarWitness.Audio.VirtualMic.play_notice/1`, which
  requires the "EarWitness Microphone" virtual device to be installed; with
  it absent, `:announce` fails closed. `play_notice/1` blocks until the clip
  has finished playing, so the notice is fully delivered before capture
  begins (the caller runs this off the LiveView process under a timeout —
  see `EarWitnessWeb.RecordingLive.Index`).

  Test seam: `config :ear_witness, :announcement_delivery_override` short-
  circuits the real device call — `:ok` reports delivered, `:fail` reports
  undelivered. `config/test.exs` sets `:ok` by default;
  `EarWitnessSpex.Fixtures.simulate_announcement_delivery_failure/0` flips it
  to `:fail` for one test.
  """

  alias EarWitness.Audio.VirtualMic

  @default_notice_clip "audio/recording-notice.wav"

  @spec authorize(:silent | :notify | :announce) ::
          {:ok, :none | :shown | :delivered} | {:error, :notice_undelivered}
  def authorize(:silent), do: {:ok, :none}
  def authorize(:notify), do: {:ok, :shown}

  def authorize(:announce) do
    case Application.get_env(:ear_witness, :announcement_delivery_override) do
      :fail -> {:error, :notice_undelivered}
      :ok -> {:ok, :delivered}
      _ -> deliver_notice()
    end
  end

  # Plays the bundled recording notice onto the outgoing voice channel.
  # Fails closed: an uninstalled virtual device or any playback error refuses
  # capture rather than recording without the promised announcement.
  defp deliver_notice do
    with true <- VirtualMic.available?(),
         :ok <- VirtualMic.play_notice(notice_clip_path()) do
      {:ok, :delivered}
    else
      _ -> {:error, :notice_undelivered}
    end
  end

  # priv/-relative so it resolves in a release regardless of cwd; overridable
  # for a custom notice clip.
  defp notice_clip_path do
    Application.get_env(:ear_witness, :notice_clip_path) ||
      Path.join(:code.priv_dir(:ear_witness), @default_notice_clip)
  end
end
