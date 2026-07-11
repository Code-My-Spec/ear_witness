defmodule TodoApp.Signals.PeakDetector do
  def detect_peaks(scores, %{alpha: alpha, min_duration: min_duration, step_size: step_size}) do
    num_frames = length(scores)
    # Assuming step size of 1 for simplicity
    precision = 1
    order = max(1, round(min_duration / precision))
    indices = find_local_maxima(scores, order)

    peak_times = for i <- indices, Enum.at(scores, i) > alpha, do: i
    boundaries = [0] ++ peak_times ++ [num_frames]

    build_binary_segmentations(boundaries, num_frames)
  end

  defp find_local_maxima(scores, order) do
    len = length(scores)

    1..(len - 2)
    |> Enum.filter(fn i ->
      Enum.slice(scores, i - 1, 3)
      |> case do
        [prev, curr, next] -> curr > prev and curr > next
        _ -> false
      end
    end)
  end

  defp build_binary_segmentations(boundaries, num_frames) do
    segments = Enum.chunk_every(boundaries, 2, 1, :discard)

    Enum.reduce(0..(num_frames - 1), [], fn i, acc ->
      if Enum.any?(segments, fn [start, stop] -> start <= i and i < stop end),
        do: [1 | acc],
        else: [0 | acc]
    end)
    |> Enum.reverse()
  end
end
