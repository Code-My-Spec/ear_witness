defmodule EarWitnessWeb.RecordingLive.Format do
  @moduledoc "Small display-formatting helpers shared by RecordingLive.Index and .Show."

  @doc """
  Formats a duration in seconds as a clock string — `M:SS` under an hour,
  `H:MM:SS` at or beyond one hour.

      iex> EarWitnessWeb.RecordingLive.Format.duration(0.1)
      "0:00"
      iex> EarWitnessWeb.RecordingLive.Format.duration(10_800)
      "3:00:00"
  """
  @spec duration(number()) :: String.t()
  def duration(seconds) when is_number(seconds) do
    total = trunc(seconds)
    hours = div(total, 3_600)
    minutes = total |> rem(3_600) |> div(60)
    secs = rem(total, 60)

    case hours do
      0 -> pad("#{minutes}:", secs)
      _ -> pad("#{hours}:#{pad("", minutes)}:", secs)
    end
  end

  defp pad(prefix, value), do: prefix <> String.pad_leading(Integer.to_string(value), 2, "0")

  @doc "Formats capture channels for display, e.g. `[:microphone, :system_audio]` -> \"microphone + system audio\"."
  @spec channels(list(atom())) :: String.t()
  def channels(channels) do
    Enum.map_join(channels, " + ", fn
      :microphone -> "microphone"
      :system_audio -> "system audio"
    end)
  end
end
