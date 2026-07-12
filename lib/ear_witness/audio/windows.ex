defmodule EarWitness.Audio.Windows do
  defstruct([
    :window_size,
    :step_size,
    :steps_per_frame,
    :max_binaries,
    :on_step_change,
    :sample_rate,
    :model,
    :byte_index,
    :step_index,
    :buffers,
    :binaries,
    :data,
    :aggregated_data
  ])

  def new(opts) do
    window_size = Keyword.get(opts, :window_size) || raise("Window size required")
    step_size = Keyword.get(opts, :step_size) || raise("Step size required")
    steps_per_frame = Integer.floor_div(window_size, step_size)
    max_binaries = Keyword.get(opts, :max_binaries, steps_per_frame)
    on_step_change = Keyword.get(opts, :on_step_change, fn state -> state end)

    if Integer.mod(window_size, step_size) != 0,
      do: raise("Window size not divisible by step size")

    %__MODULE__{
      sample_rate: Keyword.get(opts, :sample_rate) || raise("Step size required"),
      window_size: window_size,
      step_size: step_size,
      steps_per_frame: steps_per_frame,
      max_binaries: max_binaries,
      on_step_change: on_step_change,
      model: Keyword.get(opts, :model),
      byte_index: 0,
      step_index: 0,
      buffers: [],
      binaries: [],
      data: [],
      aggregated_data: []
    }
  end

  def handle_buffer(%__MODULE__{} = state, %{payload: payload} = buffer) do
    %{
      byte_index: byte_index,
      step_size: step_size,
      step_index: step_index,
      buffers: buffers,
      steps_per_frame: steps_per_frame
    } = state

    payload_size = byte_size(payload)
    new_byte_index = byte_index + payload_size
    new_step_index = trunc(new_byte_index / step_size)
    step_change = new_step_index > step_index
    exceeds_aggregation_threshold = new_step_index >= steps_per_frame + 1

    state
    |> trim_excess_binaries()
    |> Map.put(:byte_index, new_byte_index)
    |> Map.put(:step_index, new_step_index)
    |> accumulate_binaries(payload, step_change)
    |> handle_step_change(step_change)
    |> handle_aggregation(step_change and exceeds_aggregation_threshold)
    |> Map.put(:buffers, [buffer | buffers])
  end

  defp trim_excess_binaries(%{max_binaries: :inf} = state), do: state

  defp trim_excess_binaries(%{max_binaries: max_binaries, binaries: binaries} = state) do
    binaries =
      case Enum.count(binaries) > max_binaries do
        true -> Enum.take(binaries, max_binaries)
        false -> binaries
      end

    Map.put(state, :binaries, binaries)
  end

  defp accumulate_binaries(%{binaries: []} = state, data, false),
    do: Map.put(state, :binaries, [data])

  defp accumulate_binaries(%{binaries: binaries} = state, data, false) do
    [head | tail] = binaries
    Map.put(state, :binaries, [head <> data | tail])
  end

  defp accumulate_binaries(state, data, true) do
    %{binaries: binaries, step_index: step_index, byte_index: byte_index, step_size: step_size} =
      state

    payload_size = byte_size(data)
    [head | tail] = binaries
    end_of_frame = step_index * step_size
    remainder = payload_size - (byte_index - end_of_frame)

    IO.puts(
      "Byte index #{byte_index} with size #{payload_size} exceeded frame #{end_of_frame} at step index #{step_index}, appending #{remainder} bytes"
    )

    <<payload_head::binary-size(^remainder), payload_tail::binary>> = data
    Map.put(state, :binaries, [payload_tail, head <> payload_head | tail])
  end

  defp handle_step_change(state, false), do: state

  defp handle_step_change(%{on_step_change: step_change_handler} = state, true) do
    step_change_handler.(state)
  end

  defp handle_aggregation(state, false), do: state

  defp handle_aggregation(%{aggregated_data: data} = state, true) do
    windows = fetch_windows(state)
    steps = fetch_steps(windows, state)
    aggregate = aggregate_steps(steps, state)

    Map.put(state, :aggregated_data, [aggregate | data])
  end

  def fetch_windows(state) do
    %{steps_per_frame: steps_per_frame, step_index: step_index, step_size: step_size, data: data} =
      state

    indexes =
      (step_index - 2 * steps_per_frame)..(step_index - steps_per_frame - 1)
      |> Enum.map(&(&1 * step_size))
      |> Enum.filter(&(&1 >= 0))

    IO.puts("We will find windows at #{inspect(indexes)} for step index #{step_index}")

    indexes
    |> Enum.map(fn step_index ->
      Enum.find(data, &(&1.start_index == step_index))
    end)
    |> Enum.reject(&is_nil(&1))
  end

  def fetch_steps(windows, state) do
    %{
      step_size: step_size,
      sample_rate: sample_rate,
      window_size: window_size
    } = state

    [%{scd: scd} | _] = windows
    {n} = Nx.shape(scd)
    actual_sample_duration_ms = bytes_to_ms(window_size, sample_rate) / n

    windows
    |> Enum.reverse()
    |> inspect_windows()
    |> Enum.with_index()
    |> Enum.map(fn {%{scd: scd} = window, index} ->
      window_start_time_ms = bytes_to_ms(window.start_index, sample_rate)
      window_end_time_ms = bytes_to_ms(window.end_index, sample_rate)
      relative_step_start_time_ms = bytes_to_ms(index * step_size, sample_rate)
      relative_step_end_time_ms = bytes_to_ms((index + 1) * step_size, sample_rate)
      absolute_step_start_time_ms = window_start_time_ms + relative_step_start_time_ms
      absolute_step_end_time_ms = window_start_time_ms + relative_step_end_time_ms
      start_sample_index = trunc(relative_step_start_time_ms / actual_sample_duration_ms)
      end_sample_index = ceil(relative_step_end_time_ms / actual_sample_duration_ms)

      "#{index}th step of window. Window from #{window_start_time_ms} to #{window_end_time_ms}. Step from #{absolute_step_start_time_ms} to #{absolute_step_end_time_ms}. Start sample is #{start_sample_index}. End sample is #{end_sample_index}"
      |> IO.puts()

      %{
        start_sample_index: start_sample_index,
        end_sample_index: end_sample_index,
        start_time: absolute_step_start_time_ms,
        actual_sample_duration: actual_sample_duration_ms,
        scd: Nx.slice(scd, [start_sample_index], [end_sample_index - start_sample_index])
      }
    end)
  end

  def inspect_windows(windows) do
    Enum.reduce(windows, "", fn %{start_index: start_index, end_index: end_index}, acc ->
      acc <> "start index: #{start_index}, end_index: #{end_index}\n"
    end)
    |> IO.puts()

    windows
  end

  def aggregate_steps(steps, _state) do
    start_time =
      steps
      |> Enum.map(& &1.start_time)
      |> Enum.reduce(fn start_time, acc ->
        if start_time == acc, do: acc, else: raise("Invalid start time")
      end)

    sample_duration =
      steps
      |> Enum.map(& &1.actual_sample_duration)
      |> Enum.reduce(fn sample_duration, acc ->
        if sample_duration == acc, do: acc, else: raise("Invalid duration")
      end)

    IO.puts("Aggregating steps")

    scd =
      steps
      |> Enum.map(& &1.scd)
      |> Nx.stack()
      |> Nx.mean(axes: [0])

    %{start_time: start_time, duration: sample_duration, scd: scd}
  end

  defp zero_or_greater(number) when number < 0, do: 0
  defp zero_or_greater(number), do: number

  def bytes_to_ms(count_bytes, sample_rate) do
    count_bytes * (1 / 4) * 1000 / sample_rate
  end
end
