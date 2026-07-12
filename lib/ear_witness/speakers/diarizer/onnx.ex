defmodule EarWitness.Speakers.Diarizer.Onnx do
  @moduledoc """
  Real, on-device diarizer: pyannote's `segmentation-3.0` ONNX model
  (VAD + local up-to-3-speaker segmentation, powerset encoded: 7
  classes — non-speech, A, B, C, A+B, A+C, B+C) run once over the whole
  recording, speaker turns recovered from its per-frame class
  predictions, and each confident turn's own WeSpeaker ResNet34 voice
  embedding (`EarWitness.Speakers.Diarizer.Embedding`) clustered
  (`EarWitness.Speakers.Diarizer.SpectralClustering`) into consistent
  speaker identities for the whole recording — the same embeddings then
  double as the cross-recording matching signal (see
  `EarWitness.Speakers.resolve_speaker/1`).

  Clustering runs on voice embeddings rather than the segmentation
  model's per-turn class-activation profile, deliberately: the
  segmentation model's local "A"/"B"/"C" speaker slot is only
  guaranteed consistent within its own short effective context. On
  clean audio — e.g. two people trading solo turns with a silence gap
  between each — the model can (and does) reuse the same local slot for
  every turn even though the voices alternate, so an activation-profile
  feature is nearly identical across turns and collapses everyone into
  one cluster. Voice embeddings don't have that failure mode: they're
  extracted per turn from that turn's own audio and genuinely separate
  distinct voices, both within a recording and across recordings.

  Whole-file single pass, not the sliding-window-plus-overlap-add
  aggregation pyannote's own pipeline uses for long recordings (a partial,
  unfinished attempt at that lived in `EarWitness.Audio.SpeakerDiarizationSplitter`
  and `Windows`, built for the now-removed Membrane live-capture pipeline's
  streaming needs — a different concern from this post-hoc, whole-file
  pass — and was deleted with Membrane; see the miniaudio-capture ADR). A
  deliberate, documented
  scope cut for now: the segmentation model's own recurrent state
  already threads consistently across a single forward pass, so a
  single pass is honest and correct for recordings up to a few minutes;
  spectral clustering's job here is to catch the cases where the same
  underlying voice ends up split across different local A/B/C slots (or
  a local slot gets reused for a different voice) later in a longer
  clip, not to stitch windows back together. Very long recordings are
  expected to need the sliding-window path as follow-up work — see
  `.code_my_spec/architecture/decisions/speaker-diarization.md`.

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
      |> build_turns(samples, ms_per_frame)
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

  # Clusters confident runs by their own voice embedding (not the
  # segmentation model's local class-activation profile — see the
  # moduledoc for why): one WeSpeaker embedding is extracted per run,
  # from that run's own audio span, and `SpectralClustering` groups runs
  # whose voices are actually similar (its cosine affinity is exactly
  # what voice embeddings want). A run whose audio is too short to
  # embed (shouldn't happen given `@min_turn_ms`, but handled rather
  # than assumed) falls back to its own low-confidence "Unknown" turn
  # instead of being silently dropped from clustering.
  #
  # Each resulting turn carries its own run's embedding rather than one
  # embedding shared across the whole cluster: `EarWitness.Speakers`
  # already centroids every turn's embedding for a cluster before
  # matching/creating a `Speaker`, so per-run embeddings are strictly
  # more signal than a single cluster-level sample, at the cost of one
  # extra ONNX embedding call per run (the embedding model itself stays
  # loaded once via `EarWitness.Speakers.Diarizer.Models`).
  defp build_turns(runs, samples, ms_per_frame) do
    {confident_runs, ambiguous_runs} = Enum.split_with(runs, &confident?/1)

    {embeddable_runs, unembeddable_runs} =
      confident_runs
      |> Enum.map(&{&1, run_embedding(&1, samples, ms_per_frame)})
      |> Enum.split_with(fn {_run, embedding} -> not is_nil(embedding) end)

    cluster_ids =
      embeddable_runs
      |> Enum.map(fn {_run, embedding} -> embedding end)
      |> SpectralClustering.cluster()

    confident_turns =
      embeddable_runs
      |> Enum.zip(cluster_ids)
      |> Enum.map(fn {{run, embedding}, cluster_id} ->
        confident_turn(run, ms_per_frame, cluster_id, embedding)
      end)

    fallback_turns =
      Enum.map(unembeddable_runs, fn {run, _embedding} -> ambiguous_turn(run, ms_per_frame) end)

    ambiguous_turns = Enum.map(ambiguous_runs, &ambiguous_turn(&1, ms_per_frame))

    (confident_turns ++ fallback_turns ++ ambiguous_turns) |> Enum.sort_by(& &1.start_ms)
  end

  defp confident_turn(
         {_class, start_frame, end_frame, confidence},
         ms_per_frame,
         cluster_id,
         embedding
       ) do
    turn(start_frame, end_frame, ms_per_frame, cluster_id, confidence, embedding)
  end

  defp ambiguous_turn({_class, start_frame, end_frame, confidence}, ms_per_frame) do
    turn(start_frame, end_frame, ms_per_frame, nil, confidence, nil)
  end

  defp confident?({class, _start_frame, _end_frame, confidence}) do
    class in @single_speaker_classes and confidence >= @confidence_threshold
  end

  # Extracts a voice embedding from a single run's own audio span.
  defp run_embedding({_class, start_frame, end_frame, _confidence}, samples, ms_per_frame) do
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
