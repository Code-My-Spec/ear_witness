defmodule EarWitness.Speakers.Diarizer.Onnx do
  @moduledoc """
  Real, on-device diarizer: pyannote's `segmentation-3.0` ONNX model
  (VAD + local up-to-3-speaker segmentation, powerset encoded: 7
  classes — non-speech, A, B, C, A+B, A+C, B+C) run once over the whole
  recording, speaker turns recovered from its per-frame class
  predictions, refined by spectral clustering
  (`EarWitness.Speakers.Diarizer.SpectralClustering`) over each turn's
  mean class-activation profile, and a WeSpeaker ResNet34 voice
  embedding (`EarWitness.Speakers.Diarizer.Embedding`) extracted per
  confident cluster for cross-recording matching (see
  `EarWitness.Speakers.resolve_speaker/1`).

  Whole-file single pass, not the sliding-window-plus-overlap-add
  aggregation pyannote's own pipeline uses for long recordings (see the
  partial, unfinished attempt at that in
  `EarWitness.Audio.SpeakerDiarizationSplitter`/`Windows` — built for
  the live-capture Membrane pipeline's streaming needs, a different
  concern from this post-hoc, whole-file pass). A deliberate, documented
  scope cut for now: the segmentation model's own recurrent state
  already threads consistently across a single forward pass, so a
  single pass is honest and correct for recordings up to a few minutes;
  spectral clustering's job here is to catch the cases where the
  model's local A/B/C slot gets reused for a different underlying voice
  later in a longer clip, not to stitch windows back together. Very
  long recordings are expected to need the sliding-window path as
  follow-up work — see `.code_my_spec/architecture/decisions/speaker-diarization.md`.

  Overlapping speech, non-speech, and any single-speaker frame the model
  itself isn't confident about are surfaced as their own low-confidence
  turns (`cluster: nil`) rather than guessed — see
  `EarWitness.Speakers.diarize_transcript/1`, which turns that into an
  "Unknown" attribution instead of misattributing it to either speaker.
  """

  @behaviour EarWitness.Speakers.Diarizer

  alias EarWitness.Recordings.Recording
  alias EarWitness.Speakers.Diarizer.{Embedding, Models, Pcm, SpectralClustering}

  @sample_rate 16_000
  @num_classes 7
  @single_speaker_classes [1, 2, 3]
  @min_turn_ms 200
  @confidence_threshold 0.85
  @min_audio_samples trunc(@sample_rate * 0.1)

  @impl true
  def diarize(%Recording{file_path: file_path}) do
    with {:ok, samples} <- Pcm.read(file_path) do
      {:ok, diarize_samples(samples)}
    end
  end

  @doc false
  # Exposed (not part of the `Diarizer` behaviour) so cassette-recording
  # scripts can run the real pipeline directly against fixture sample
  # tensors — see `EarWitnessTest.RecordedDiarizer`.
  @spec diarize_samples(Nx.Tensor.t()) :: [EarWitness.Speakers.Diarizer.turn()]
  def diarize_samples(samples) do
    if Nx.size(samples) < @min_audio_samples do
      []
    else
      log_probs = run_segmentation(samples)
      {num_frames, _classes} = Nx.shape(log_probs)
      ms_per_frame = Nx.size(samples) / max(num_frames, 1) / @sample_rate * 1000

      log_probs
      |> frame_runs()
      |> Enum.filter(&long_enough?(&1, ms_per_frame))
      |> build_turns(log_probs, samples, ms_per_frame)
    end
  end

  defp run_segmentation(samples) do
    input = samples |> Nx.reshape({1, 1, Nx.size(samples)}) |> Nx.as_type(:f32)
    {result} = Ortex.run(Models.segmentation(), {input})
    {_batch, num_frames, num_classes} = Nx.shape(result)
    result |> Nx.reshape({num_frames, num_classes}) |> Nx.backend_transfer()
  end

  # Contiguous runs of the same argmax class:
  # {class, start_frame, end_frame_exclusive, mean_confidence}
  defp frame_runs(log_probs) do
    classes = log_probs |> Nx.argmax(axis: 1) |> Nx.to_flat_list()
    confidences = log_probs |> Nx.reduce_max(axes: [1]) |> Nx.exp() |> Nx.to_flat_list()

    classes
    |> Enum.zip(confidences)
    |> Enum.with_index()
    |> Enum.chunk_by(fn {{class, _confidence}, _index} -> class end)
    |> Enum.map(&summarize_run/1)
  end

  defp summarize_run(frames) do
    {{class, _confidence}, start_index} = List.first(frames)
    {_last, end_index} = List.last(frames)

    mean_confidence =
      frames |> Enum.map(fn {{_class, confidence}, _index} -> confidence end) |> mean()

    {class, start_index, end_index + 1, mean_confidence}
  end

  defp long_enough?({_class, start_frame, end_frame, _confidence}, ms_per_frame) do
    (end_frame - start_frame) * ms_per_frame >= @min_turn_ms
  end

  defp build_turns(runs, log_probs, samples, ms_per_frame) do
    {confident_runs, ambiguous_runs} = Enum.split_with(runs, &confident?/1)

    cluster_ids =
      confident_runs
      |> Enum.map(&mean_activation(&1, log_probs))
      |> SpectralClustering.cluster()

    confident_turns =
      confident_runs
      |> Enum.zip(cluster_ids)
      |> Enum.group_by(&elem(&1, 1), &elem(&1, 0))
      |> Enum.flat_map(&turns_for_cluster(&1, samples, ms_per_frame))

    ambiguous_turns =
      Enum.map(ambiguous_runs, fn {_class, start_frame, end_frame, confidence} ->
        turn(start_frame, end_frame, ms_per_frame, nil, confidence, nil)
      end)

    (confident_turns ++ ambiguous_turns) |> Enum.sort_by(& &1.start_ms)
  end

  defp turns_for_cluster({cluster_id, cluster_runs}, samples, ms_per_frame) do
    embedding = cluster_embedding(cluster_runs, samples, ms_per_frame)

    Enum.map(cluster_runs, fn {_class, start_frame, end_frame, confidence} ->
      turn(start_frame, end_frame, ms_per_frame, cluster_id, confidence, embedding)
    end)
  end

  defp confident?({class, _start_frame, _end_frame, confidence}) do
    class in @single_speaker_classes and confidence >= @confidence_threshold
  end

  defp mean_activation({_class, start_frame, end_frame, _confidence}, log_probs) do
    log_probs
    |> Nx.slice([start_frame, 0], [end_frame - start_frame, @num_classes])
    |> Nx.exp()
    |> Nx.mean(axes: [0])
    |> Nx.to_flat_list()
  end

  # Extracts one voice embedding per cluster, from the audio underneath
  # its single longest turn (long enough to be a reliable sample of the
  # voice, and avoids diluting the embedding by stitching non-contiguous
  # audio together).
  defp cluster_embedding(cluster_runs, samples, ms_per_frame) do
    {_class, start_frame, end_frame, _confidence} =
      Enum.max_by(cluster_runs, fn {_class, start_frame, end_frame, _confidence} ->
        end_frame - start_frame
      end)

    total_samples = Nx.size(samples)
    start_sample = start_frame |> frame_to_sample(ms_per_frame) |> max(0) |> min(total_samples)

    end_sample =
      end_frame |> frame_to_sample(ms_per_frame) |> max(start_sample) |> min(total_samples)

    samples
    |> Nx.slice([start_sample], [end_sample - start_sample])
    |> Embedding.extract()
  end

  defp frame_to_sample(frame, ms_per_frame), do: round(frame * ms_per_frame / 1000 * @sample_rate)

  defp turn(start_frame, end_frame, ms_per_frame, cluster, confidence, embedding) do
    %{
      start_ms: round(start_frame * ms_per_frame),
      end_ms: round(end_frame * ms_per_frame),
      cluster: cluster,
      confidence: confidence,
      embedding: embedding
    }
  end

  defp mean(values), do: Enum.sum(values) / length(values)
end
