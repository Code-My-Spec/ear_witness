defmodule EarWitness.Speakers.Diarizer.SpectralClustering do
  @moduledoc """
  Clusters a small set of feature vectors — one per detected speaker
  turn, its WeSpeaker voice embedding (see
  `EarWitness.Speakers.Diarizer.Onnx`) — into consistent speaker
  identities for the whole recording.

  Standard spectral clustering (Ng-Jordan-Weiss): cosine affinity matrix
  -> row-wise sparsified (see `sparsify/1`) -> symmetric normalized
  graph Laplacian -> eigendecomposition (`Nx.LinAlg.eigh/1`) -> the
  number of clusters `k` chosen by the eigengap heuristic (bounded to
  `1..3`, since the segmentation model only ever identifies up to 3
  concurrent local speakers) -> k-means over the rows of the top-`k`
  eigenvectors.

  This exists because the segmentation model's local "A/B/C" slot for a
  turn is only guaranteed consistent within the model's own effective
  context — for turns far apart in a longer recording, two turns both
  locally labeled "A" are not guaranteed to be the same person, and on
  clean audio the model can reuse the same local slot for every turn
  even when the underlying voices alternate. This step re-groups turns
  by actual voice similarity instead of trusting the model's raw local
  label. Scaled for the handful of turns one recording produces — not a
  general large-N spectral clustering implementation.
  """

  @max_k 3

  # Row-relative sparsification threshold for `sparsify/1` — see there
  # for why. `0.7` was picked empirically (verified against a real
  # two-speaker recording, `test/fixtures/diarize.raw`, and a clean
  # alternating-solo-speaker recording): the whole `0.6..0.85` range
  # produces identical, correct clustering on both, so this isn't a
  # finely-tuned edge value.
  @relative_threshold 0.7

  @doc """
  Returns one cluster index (`0`-based, contiguous) per input feature
  vector. A single input always gets cluster `0`; the empty list
  returns `[]`.
  """
  @spec cluster([[float()]]) :: [non_neg_integer()]
  def cluster([]), do: []
  def cluster([_single]), do: [0]

  def cluster(feature_vectors) do
    x = Nx.tensor(feature_vectors)
    affinity = x |> cosine_affinity() |> sparsify()
    laplacian = normalized_laplacian(affinity)
    # `Nx.LinAlg.eigh/1` returns eigenvalues/-vectors sorted *descending*;
    # the eigengap heuristic below wants smallest-first (standard
    # Ng-Jordan-Weiss convention), so flip both, keeping each eigenvector
    # column matched to its eigenvalue.
    {eigenvalues, eigenvectors} = ascending(Nx.LinAlg.eigh(laplacian))

    k = choose_k(eigenvalues, length(feature_vectors))
    points = spectral_embedding(eigenvectors, k)

    kmeans(points, k)
  end

  defp cosine_affinity(x) do
    norm = x |> Nx.pow(2) |> Nx.sum(axes: [1], keep_axes: true) |> Nx.sqrt()
    safe_norm = Nx.select(Nx.equal(norm, 0), Nx.tensor(1.0), norm)
    unit = Nx.divide(x, safe_norm)
    unit |> Nx.dot(Nx.transpose(unit)) |> Nx.max(0.0)
  end

  # Real voice embeddings, unlike the segmentation model's own
  # class-activation profiles, rarely form a near-block-diagonal
  # affinity matrix: even turns from two genuinely different speakers
  # tend to share modest positive cosine similarity (channel, room
  # acoustics, and the embedding model's own imperfections all add
  # baseline similarity), so a fully-connected graph's normalized cut
  # between real speakers is often not small enough for the eigengap
  # heuristic to notice — every row stays meaningfully connected to
  # every other row, masking real cluster structure.
  #
  # Dropping each row's edges that are weak *relative to that row's own
  # strongest connection* (a standard spectral-clustering affinity
  # refinement — see e.g. Wang et al. 2018's row-wise thresholding for
  # speaker diarization) sharpens that structure: a turn's true
  # same-speaker matches stay close to its best match, while
  # cross-speaker matches fall well short of it, regardless of the
  # recording's overall noise floor. A row-mean threshold was tried
  # first and rejected — with as few as 3 turns from a single real
  # speaker, dropping "below average" edges can sever a genuinely
  # single cluster into two, since one of only two neighbors is always
  # somewhat below the mean by construction. Thresholding relative to
  # the row's *max* instead only drops edges that are meaningfully
  # weaker than that row's best match, so a uniformly-similar
  # single-speaker row stays fully connected. Symmetrized by keeping an
  # edge if *either* endpoint considers it strong enough, so one noisy
  # row can't unilaterally sever a real connection.
  defp sparsify(affinity) do
    {n, _n} = Nx.shape(affinity)
    off_diagonal = Nx.subtract(affinity, Nx.multiply(Nx.eye(n), affinity))
    row_max = Nx.reduce_max(off_diagonal, axes: [1], keep_axes: true)
    threshold = Nx.multiply(row_max, @relative_threshold)
    thresholded = Nx.select(Nx.greater_equal(off_diagonal, threshold), off_diagonal, 0.0)
    Nx.max(thresholded, Nx.transpose(thresholded))
  end

  defp normalized_laplacian(affinity) do
    {n, _n} = Nx.shape(affinity)
    degree = Nx.sum(affinity, axes: [1])
    d_inv_sqrt = Nx.select(Nx.equal(degree, 0), Nx.tensor(0.0), Nx.rsqrt(degree))
    scaling = Nx.multiply(Nx.eye(n), d_inv_sqrt)
    normalized_affinity = scaling |> Nx.dot(affinity) |> Nx.dot(scaling)
    Nx.subtract(Nx.eye(n), normalized_affinity)
  end

  defp ascending({eigenvalues, eigenvectors}) do
    {n} = Nx.shape(eigenvalues)
    reversed = Nx.tensor(Enum.to_list((n - 1)..0//-1))
    {Nx.take(eigenvalues, reversed), Nx.take(eigenvectors, reversed, axis: 1)}
  end

  defp choose_k(eigenvalues, n) do
    max_k = min(@max_k, n)

    gaps =
      eigenvalues
      |> Nx.to_flat_list()
      |> Enum.take(max_k + 1)
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.map(fn [a, b] -> b - a end)

    case gaps do
      [] -> 1
      _ -> (gaps |> Enum.with_index() |> Enum.max_by(&elem(&1, 0)) |> elem(1)) + 1
    end
  end

  defp spectral_embedding(eigenvectors, k) do
    normalized =
      eigenvectors
      |> Nx.slice_along_axis(0, k, axis: 1)
      |> row_normalize()

    Nx.to_list(normalized)
  end

  defp row_normalize(matrix) do
    norm = matrix |> Nx.pow(2) |> Nx.sum(axes: [1], keep_axes: true) |> Nx.sqrt()
    safe_norm = Nx.select(Nx.equal(norm, 0), Nx.tensor(1.0), norm)
    Nx.divide(matrix, safe_norm)
  end

  # -- k-means, in plain Elixir over point lists: k and the number of
  # turns are both small (single digits to low tens), so this is far
  # simpler to get right than doing it in Nx tensor ops. --

  defp kmeans(points, k) when k >= length(points) do
    Enum.to_list(0..(length(points) - 1))
  end

  defp kmeans(points, k) do
    points
    |> farthest_point_init(k)
    |> lloyd(points, 20)
  end

  defp farthest_point_init(points, k) do
    [first | _] = points

    Enum.reduce(2..k//1, [first], fn _, chosen ->
      next =
        Enum.max_by(points, fn p -> chosen |> Enum.map(&squared_distance(p, &1)) |> Enum.min() end)

      chosen ++ [next]
    end)
  end

  defp lloyd(centroids, points, 0), do: assign(points, centroids)

  defp lloyd(centroids, points, iterations_left) do
    assignments = assign(points, centroids)
    new_centroids = recompute_centroids(points, assignments, centroids)

    if new_centroids == centroids do
      assignments
    else
      lloyd(new_centroids, points, iterations_left - 1)
    end
  end

  defp assign(points, centroids) do
    Enum.map(points, fn point ->
      centroids
      |> Enum.with_index()
      |> Enum.min_by(fn {centroid, _index} -> squared_distance(point, centroid) end)
      |> elem(1)
    end)
  end

  defp recompute_centroids(points, assignments, old_centroids) do
    groups = points |> Enum.zip(assignments) |> Enum.group_by(&elem(&1, 1), &elem(&1, 0))

    old_centroids
    |> Enum.with_index()
    |> Enum.map(fn {old_centroid, index} ->
      case Map.get(groups, index) do
        nil -> old_centroid
        cluster_points -> mean_point(cluster_points)
      end
    end)
  end

  defp mean_point(points) do
    dimensions = points |> hd() |> length()
    zero = List.duplicate(0.0, dimensions)

    points
    |> Enum.reduce(zero, fn point, acc -> Enum.zip_with(point, acc, &+/2) end)
    |> Enum.map(&(&1 / length(points)))
  end

  defp squared_distance(a, b),
    do: a |> Enum.zip_with(b, fn x, y -> (x - y) * (x - y) end) |> Enum.sum()
end
