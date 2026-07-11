defmodule TodoApp.Audio.SpeakerDiarizationSplitter do
  use Membrane.Filter

  alias Membrane.{RawAudio, Buffer}
  alias TodoApp.Audio.Windows

  @sample_rate 16_000
  @window_duration_milliseconds 10030
  @window_duration Membrane.Time.milliseconds(@window_duration_milliseconds)
  @chunk_duration_milliseconds 17
  @chunk_duration Membrane.Time.milliseconds(@chunk_duration_milliseconds)
  @steps_per_frame 2
  @time_axis 0
  @speaker_axis 1

  def_input_pad(:input,
    accepted_format: %RawAudio{sample_format: :f32le, channels: 1, sample_rate: @sample_rate}
  )

  def_output_pad(:output,
    accepted_format: %RawAudio{sample_format: :f32le, channels: 1, sample_rate: @sample_rate}
  )

  @impl true
  def handle_init(_ctx, _opts) do
    {[],
     %{
       buffers: [],
       binaries: [<<>>],
       scores: [],
       byte_index: 0,
       step_index: 0
     }}
  end

  @impl true
  def handle_stream_format(:input, stream_format, _ctx, state) do
    window_size = RawAudio.time_to_bytes(@window_duration, stream_format)
    chunk_size = RawAudio.time_to_bytes(@chunk_duration, stream_format)

    model =
      Ortex.load(Path.join([:code.priv_dir(:todo_app), "models", "segmentation-3.0.onnx"]))

    IO.inspect(@window_duration / 591, label: :actual_chunk_size)

    IO.inspect(RawAudio.time_to_bytes(@window_duration / 591, stream_format),
      label: :sample_duration_bytes
    )

    state =
      state
      |> Map.put(
        :windows,
        Windows.new(
          window_size: window_size,
          chunk_size: chunk_size,
          step_size: trunc(window_size / @steps_per_frame),
          data: %{scores: []},
          on_step_change: &on_step_change/1,
          model: model,
          sample_rate: @sample_rate
        )
      )
      |> Map.put(:window_size, window_size)
      |> Map.put(:chunk_size, chunk_size)
      |> Map.put(:step_size, trunc(window_size / @steps_per_frame))

    {[stream_format: {:output, stream_format}], state}
  end

  @impl true
  def handle_buffer(:input, %Buffer{} = buffer, _ctx, %{windows: windows} = state) do
    {[buffer: {:output, buffer}],
     Map.put(state, :windows, Windows.handle_buffer(windows, buffer))}
  end

  @impl true
  def handle_end_of_stream(_pad, _ctx, state) do
    IO.puts("End of stream")
    {[], Map.put(state, :windows, [[], [], []])}
  end

  def on_step_change(%{data: data, steps_per_frame: steps_per_frame, binaries: binaries} = state) do
    if Enum.count(binaries) >= steps_per_frame + 1 do
      new_data =
        calculate_scores(state)
        |> calculate_speaker_change_detection()
        |> put_hamming_window()

      Map.put(state, :data, [new_data | data])
    else
      state
    end
  end

  def calculate_scores(state) do
    %{
      binaries: binaries,
      step_index: step_index,
      step_size: step_size,
      steps_per_frame: steps_per_frame
    } =
      state

    binary =
      binaries
      |> get_tail()
      |> Enum.take(steps_per_frame)
      |> Enum.reduce(<<>>, fn completed, acc -> acc <> completed end)

    end_index = step_index * step_size
    start_index = end_index - byte_size(binary)

    "Generating scores for start_index #{start_index}, end_index #{end_index}. There are #{byte_size(binary)} bytes in the binary."
    |> IO.puts()

    %{
      scores: get_scores(binary, state),
      start_index: start_index,
      end_index: end_index
    }
  end

  def calculate_speaker_change_detection(%{scores: scores} = data) do
    scd =
      scores
      |> Nx.diff(axis: @time_axis, order: 1)
      |> Nx.abs()
      |> Nx.reduce_max(axes: [@speaker_axis])

    Map.put(data, :scd, scd)
  end

  def prepare_window(%{scores: scores}) do
    {frames_per_window, _num_classes} = Nx.shape(scores)
    hamming_window = hamming_window(frames_per_window)

    Nx.multiply(scores, hamming_window)
  end

  def aggregate_windows(first_window, second_window, opts \\ []) do
    _epsilon = Keyword.get(opts, :epsilon, 1.0e-12)
    _missing = Keyword.get(opts, :missing, :nan)

    {1, frames_per_window, num_classes} = Nx.shape(first_window)
    num_frames_per_chunk = div(frames_per_window, 2)

    _hamming_window = hamming_window(frames_per_window)
    # hamming_window = Nx.broadcast(1.0, {num_frames_per_chunk, 1})

    first_half = Nx.slice(second_window, [0, 0, 0], [1, num_frames_per_chunk, num_classes])

    _second_half =
      Nx.slice(first_half, [0, num_frames_per_chunk, 0], [1, num_frames_per_chunk, num_classes])

    # mask = Nx.is_nan(combined)
    # combined = Nx.replace(combined, mask, 0.0)

    # aggregated_output = Nx.broadcast(0.0, {num_frames_per_chunk, num_classes})
    # overlapping_chunk_count = Nx.broadcast(0.0, {num_frames_per_chunk, num_classes})
    # aggregated_mask = Nx.broadcast(0.0, {num_frames_per_chunk, num_classes})

    # Enum.each(0..(num_frames_per_chunk - 1), fn index ->
    #   aggregated_output = Nx.add(aggregated_output,
    #     Nx.multiply(Nx.multiply(Nx.multiply(Nx.slice(combined, [index, 0], [1, num_classes]), Nx.slice(mask, [index, 0], [1, num_classes])),
    #     Nx.slice(hamming_window, [index, 0], [1, 1])),
    #     Nx.slice(warm_up_window, [index, 0], [1, 1]))
    #   )

    #   overlapping_chunk_count = Nx.add(overlapping_chunk_count,
    #     Nx.multiply(Nx.multiply(Nx.slice(mask, [index, 0], [1, num_classes]),
    #     Nx.slice(hamming_window, [index, 0], [1, 1])),
    #     Nx.slice(warm_up_window, [index, 0], [1, 1]))
    #   )

    #   aggregated_mask = Nx.max(aggregated_mask, Nx.slice(mask, [index, 0], [1, num_classes]))
    # end)

    # average =  Nx.divide(aggregated_output, Nx.max(overlapping_chunk_count, epsilon))

    # average = Nx.map(average, fn x -> if x == 0.0, do: missing, else: x end)

    # %SlidingWindowFeature{data: average}
  end

  defp put_hamming_window(%{scores: scores} = data) do
    {n, _} = Nx.shape(scores)
    Map.put(data, :hamming_window, hamming_window(n))
  end

  def hamming_window(m) when is_integer(m) and m > 1 do
    0..(m - 1)
    |> Enum.map(&calculate_hamming_value(&1, m))
    |> Nx.tensor()
  end

  defp calculate_hamming_value(n, m) do
    0.54 - 0.46 * :math.cos(2 * :math.pi() * n / (m - 1))
  end

  defp get_scores(binary, %{model: model}) do
    tensor = Nx.from_binary(binary, :f32)
    input = Nx.reshape(tensor, {1, 1, div(byte_size(binary), 4)})
    {result} = Ortex.run(model, {input})
    {1, num_samples, num_classes} = Nx.shape(result)

    Nx.reshape(result, {num_samples, num_classes})
    |> Nx.backend_transfer()
  end

  defp get_tail([_ | tail]), do: tail
end
