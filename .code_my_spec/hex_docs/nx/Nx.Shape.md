# Nx.Shape



## validate!/2

Validates a given shape with `kind`.

## Examples

    iex> Nx.Shape.validate!({1, 2, 3}, :window_dimensions)
    {1, 2, 3}

    iex> Nx.Shape.validate!({0, 2, 3}, :window_dimensions)
    ** (ArgumentError) invalid dimension in axis 0 found in window_dimensions. Each dimension must be a positive integer, got 0 in shape {0, 2, 3}

## to_algebra/4

Converts a shape to an algebra document for inspection.

## to_string/2

Converts shape and name to a string.

## Examples

    iex> Nx.Shape.to_string({1, 2, 3}, [:foo, nil, :bat])
    "[foo: 1][2][bat: 3]"

## named_axes!/2

Validates the names of axes.

## find_name!/2

Finds the axis for the given name.

## reshape/2

Reshapes `old_shape` to `new_shape`.

The product of all dimensions in `old_shape` must match the
product of all dimensions in `new_shape`. You may optionally
specify an `:auto` dimension to infer the shape of that dimension.

## Examples

    iex> Nx.Shape.reshape({}, {})
    {}

    iex> Nx.Shape.reshape({2, 3}, {1, 6})
    {1, 6}

    iex> Nx.Shape.reshape({2, 2, 2}, {:auto, 4})
    {2, 4}

## Error cases

    iex> Nx.Shape.reshape({2, 2, 2}, {2, 3})
    ** (ArgumentError) cannot reshape, current shape {2, 2, 2} is not compatible with new shape {2, 3}

    iex> Nx.Shape.reshape({1, 3}, {:auto, 4})
    ** (ArgumentError) cannot reshape, current shape {1, 3} is not compatible with new shape {4}

## broadcast!/4

Broadcasts a shape to a new shape.

The dimensions of `shape` is expanded to match the
dimensions of `new_shape` according to the axes
mapping.

## Examples

### Scalars

    iex> Nx.Shape.broadcast!({}, {4, 2, 1, 5}, [])
    :ok

    iex> Nx.Shape.broadcast!({}, {}, [])
    :ok

### n-D shapes

    iex> Nx.Shape.broadcast!({1}, {2, 3, 4}, [2])
    :ok

    iex> Nx.Shape.broadcast!({4, 2, 3}, {4, 3, 4, 2, 3}, [2, 3, 4])
    :ok

### Custom axes

    iex> Nx.Shape.broadcast!({2}, {2, 3}, [0])
    :ok

## Error cases

    iex> Nx.Shape.broadcast!({4, 2, 2}, {1, 1}, [0, 1, 2])
    ** (ArgumentError) cannot broadcast tensor of dimensions {4, 2, 2} to {1, 1} with axes [0, 1, 2]

    iex> Nx.Shape.broadcast!({2, 2}, {2, 2, 2}, [1, 0])
    ** (ArgumentError) broadcast axes must be ordered, got 0 after 1

## binary_broadcast/4

Broadcasts two shapes to a common shape.

The dimensions of either shape can be expanded to match
the dimension of the other. This differs from a normal
broadcast, where one shapes dimensions remain fixed,
while the other's are expanded to match.

## Examples

### Scalar Shapes

    iex> Nx.Shape.binary_broadcast({}, [], {}, [])
    {{}, []}
    iex> Nx.Shape.binary_broadcast({}, [], {4, 2, 1, 5}, [:batch, nil, :data, nil])
    {{4, 2, 1, 5}, [:batch, nil, :data, nil]}

### n-D Shapes

    iex> Nx.Shape.binary_broadcast({8, 1, 6, 1}, [:batch, nil, :data, nil], {7, 1, 5}, [:time, :data, nil])
    {{8, 7, 6, 5}, [:batch, :time, :data, nil]}
    iex> Nx.Shape.binary_broadcast({7, 1, 5}, [:time, :data, nil], {8, 1, 6, 1},  [:batch, nil, :data, nil])
    {{8, 7, 6, 5}, [:batch, :time, :data, nil]}
    iex> Nx.Shape.binary_broadcast({5, 4}, [nil, nil], {1}, [:data])
    {{5, 4}, [nil, :data]}
    iex> Nx.Shape.binary_broadcast({3, 1}, [:x, :y], {15, 3, 5}, [:batch, :x, nil])
    {{15, 3, 5}, [:batch, :x, :y]}

## Error cases

    iex> Nx.Shape.binary_broadcast({4, 2, 5}, [nil, nil, nil], {3, 2, 5}, [:batch, :x, :y])
    ** (ArgumentError) cannot broadcast tensor of dimensions {4, 2, 5} to {3, 2, 5}

    iex> Nx.Shape.binary_broadcast({1, 2, 5}, [:batch, :x, :y], {3, 2, 5}, [:time, :x, :y])
    ** (ArgumentError) cannot merge name :batch on axis 0 with name :time on axis 0

## contract/4

Contracts a shape along the given axes.

It expects the axes to have been normalized.

## Examples

    iex> Nx.Shape.contract({4, 1, 2}, [1], [:batch, :x, :y], false)
    {{4, 2}, [:batch, :y]}

    iex> Nx.Shape.contract({2, 4, 6, 5}, [1, 3], [:batch, :x, :y, :z], false)
    {{2, 6}, [:batch, :y]}

    iex> Nx.Shape.contract({1, 2, 3}, [], [:batch, :x, :y], false)
    {{1, 2, 3}, [:batch, :x, :y]}

    iex> Nx.Shape.contract({4, 2, 8}, [2], [:x, :y, :z], false)
    {{4, 2}, [:x, :y]}

    iex> Nx.Shape.contract({4, 2, 8}, [2], [:x, :y, :z], true)
    {{4, 2, 1}, [:x, :y, :z]}

## transpose/3

Transposes a shape according to the given permutation.

## Examples

  iex> Nx.Shape.transpose({4, 8, 2, 1}, [1, 0, 3, 2], [:batch, :channels, :height, :width])
  {{8, 4, 1, 2}, [:channels, :batch, :width, :height]}

## Error cases

  iex> Nx.Shape.transpose({4, 8, 2, 1}, [0, 1, 2], [:batch, nil, nil, nil])
  ** (ArgumentError) expected length of permutation (3) to match rank of shape (4)

## zip_reduce/6

Computes the shape for zip_reduce.

In order for the dimensions to be correct, the value of each shape
at the given axes must match. It expects axes to have already been
normalized.

## Examples

    iex> Nx.Shape.zip_reduce({1, 2, 3}, [0, 1], [:batch, :x, :y], {3, 1, 2}, [1, 2], [:batch, :x, :y])
    {{3, 3}, [:y, :batch]}

    iex> Nx.Shape.zip_reduce({1, 2, 3}, [0, 1], [nil, nil, nil], {1, 2, 3}, [1, 2], [nil, nil, nil])
    ** (ArgumentError) dot/zip expects shapes to be compatible, dimension 0 of left-side (1) does not equal dimension 1 of right-side (2)

    iex> Nx.Shape.zip_reduce({2, 2}, [1], [:x, :y], {2, 2}, [0], [:y, :x])
    ** (ArgumentError) operation would result in duplicate names [:x, :x], please rename your tensors to avoid duplicates

## to_padding_config/3

Returns a padding configuration based on the given pad mode
for the given input shape, kernel size and stride.

By default, interior padding is not considered in the padding
configuration.

## Examples

    iex> Nx.Shape.to_padding_config({2, 3, 2}, {2, 3, 2}, :valid)
    [{0, 0}, {0, 0}, {0, 0}]

    iex> Nx.Shape.to_padding_config({12, 12}, {2, 2}, :same)
    [{0, 1}, {0, 1}]

## Error cases

    iex> Nx.Shape.to_padding_config({2, 3, 2}, {2, 3, 2}, :foo)
    ** (ArgumentError) invalid padding mode specified, padding must be one of :valid, :same, or a padding configuration, got: :foo

## flatten/3

Flattens the given axes of the given input shape into a
single axis.

## Examples

    iex> Nx.Shape.flatten({1, 2, 3}, [nil, nil, nil], nil)
    {{6}, [nil]}

    iex> Nx.Shape.flatten({1, 2, 3}, [:batch, nil, nil], [1, 2])
    {{1, 6}, [:batch, nil]}

    iex> Nx.Shape.flatten({1, 2, 3}, [nil, nil, nil], [])
    {{1, 2, 3}, [nil, nil, nil]}

## Error cases

    iex> Nx.Shape.flatten({1, 2, 3}, [:batch, nil, nil], [0, 2])
    ** (ArgumentError) flatten axes must be consecutive

## dilate/2

Dilates the given input shape according to dilation.

## Examples

    iex> Nx.Shape.dilate({3, 3, 3}, [1, 2, 1])
    {3, 5, 3}

    iex> Nx.Shape.dilate({2, 4, 2}, [3, 1, 3])
    {4, 4, 4}

## validate_conv!/2

Early validation of conv! before remaining values are computed.

## conv/13

Output shape after a convolution.

## pool/5

Output shape after a pooling or reduce window operation.

## Examples

  iex> Nx.Shape.pool({3, 3}, {1, 2}, [1, 1], :valid, [1, 1])
  {{3, 2}, [{0, 0}, {0, 0}]}

  iex> Nx.Shape.pool({3, 2, 3}, {2, 1, 1}, [1, 2, 1], :same, [1, 1, 1])
  {{3, 1, 3}, [{0, 1}, {0, 0}, {0, 0}]}

## Error cases

  iex> Nx.Shape.pool({1, 2, 3}, {2, 1, 1}, [1, 1, 1], :valid, [1, 1, 1])
  ** (ArgumentError) window dimensions would result in empty tensor which is not currently supported in Nx, please open an issue if you'd like this behavior to change

  iex> Nx.Shape.pool({1, 2, 3}, {2, 1}, [1, 1, 1], :valid, [1, 1, 1])
  ** (ArgumentError) invalid window dimensions, rank of shape (3) does not match rank of window (2)

  iex> Nx.Shape.pool({1, 2, 3}, {2, 1, 1}, [1, 1], :valid, [1, 1, 1])
  ** (ArgumentError) invalid stride dimensions, rank of shape (3) does not match rank of stride (2)

## indexed_scalar/3

Validates the input shapes for `Nx.indexed_*/3`

## indexed/4

Validates the input shapes for `Nx.indexed_*/3`

## squeeze/3

Output shape after a squeeze operation.

## Examples

    iex> Nx.Shape.squeeze({2, 1, 1}, [1, 2], [:batch, :x, :y])
    {{2}, [:batch]}

    iex> Nx.Shape.squeeze({1, 2}, [0], [:batch, :x])
    {{2}, [:x]}

## Error cases

    iex> Nx.Shape.squeeze({2, 2, 1}, [1], [:batch, :x, :y])
    ** (ArgumentError) cannot squeeze dimensions whose sizes are not 1, got 2 for dimension 1

## pad/2

Output shape after a padding operation.

## Examples

    iex> Nx.Shape.pad({3, 2, 4}, [{0, 1, 0}, {1, 2, 0}, {1, 1, 0}])
    {4, 5, 6}

    iex> Nx.Shape.pad({}, [])
    {}

    iex> Nx.Shape.pad({2, 2}, [{1, 1, 0}, {0, 0, 0}])
    {4, 2}

    iex> Nx.Shape.pad({2, 3}, [{0, 0, 1}, {0, 0, 1}])
    {3, 5}

## Error cases

    iex> Nx.Shape.pad({2, 2, 3}, [{0, 1, 0}, {1, 2, 0}])
    ** (ArgumentError) invalid padding configuration, rank of padding configuration and shape must match

    iex> Nx.Shape.pad({2, 2, 3}, [{0, 1, -1}, {0, 0, 0}, {0, 0, 0}])
    ** (ArgumentError) invalid padding configuration, interior padding must be non-negative

## normalize_axis/4

Normalize the axis to the given shape.

## Examples

    iex> Nx.Shape.normalize_axis({4, 2, 3}, -1, [:batch, :x, :y])
    2

    iex> Nx.Shape.normalize_axis({4, 2, 1, 4}, -2, [:batch, :x, :y, :z])
    2

    iex> Nx.Shape.normalize_axis({4, 2, 1, 4}, 1, [:batch, :x, :y, :z])
    1

    iex> Nx.Shape.normalize_axis({4, 2, 1, 4}, :z, [:batch, :x, :y, :z])
    3

    iex> Nx.Shape.normalize_axis({4, 2, 1, 4}, 2, [nil, nil, nil, nil], 1)
    3

## Error cases

    iex> Nx.Shape.normalize_axis({4, 2, 5}, -4, [:batch, :x, :y])
    ** (ArgumentError) given axis (-4) invalid for shape with rank 3

    iex> Nx.Shape.normalize_axis({4, 2, 5}, 3, [:batch, :x, :y])
    ** (ArgumentError) given axis (3) invalid for shape with rank 3

    iex> Nx.Shape.normalize_axis({4, 2, 5}, :z, [:batch, :x, :y])
    ** (ArgumentError) name :z not found in tensor with names [:batch, :x, :y]

    iex> Nx.Shape.normalize_axis({4, 2, 5}, nil, [:batch, nil, nil])
    ** (ArgumentError) axis name cannot be nil

## normalize_axes/4

Normalize a list of unique axis.

See `normalize_axis/1`.

## Examples

    iex> Nx.Shape.normalize_axes({2, 3, 4}, [-1, 0], [:batch, nil])
    [2, 0]

    iex> Nx.Shape.normalize_axes({2, 3, 4}, [:batch, 1], [:batch, :x])
    [0, 1]

## Error cases

    iex> Nx.Shape.normalize_axes({2, 3, 4}, [1, 1], [nil, nil, nil])
    ** (ArgumentError) axes [1, 1] must be unique integers between 0 and 2

## transpose_axes/2

Returns the axes for transposition.

## Examples

    iex> Nx.Shape.transpose_axes({})
    []
    iex> Nx.Shape.transpose_axes({3, 2, 1})
    [2, 1, 0]

## broadcast_axes/2

Compute the broadcast axes based on the shape rank.

It doesn't validate if the remaining dimensions are
actually valid.

## Examples

    iex> Nx.Shape.broadcast_axes({2, 2, 2}, {2, 2, 2, 2})
    [1, 2, 3]

    iex> Nx.Shape.broadcast_axes({2, 2, 2}, {2, 2, 2, 2, 2})
    [2, 3, 4]

## squeeze_axes/2

Returns the axes for squeezing.

## Examples

    iex> Nx.Shape.squeeze_axes({2, 1, 1})
    [1, 2]

    iex> Nx.Shape.squeeze_axes({1, 2, 1, 3, 2, 1})
    [0, 2, 5]

## slice/4

Returns the shape after a slice.

## Examples

    iex> Nx.Shape.slice({2, 15, 30}, [1, 4, 10], [1, 1, 10], [1, 1, 3])
    {[1, 4, 10], {1, 1, 4}}

    iex> Nx.Shape.slice({2, 15, 30}, [1, 4, 25], [1, 1, 10], [1, 1, 1])
    {[1, 4, 20], {1, 1, 10}}

## Error cases

    iex> Nx.Shape.slice({2, 15, 30}, [1, 4, 10], [3, 1, 1], [1, 1, 1])
    ** (ArgumentError) length at axis 0 must be less than axis size of 2, got: 3

## put_slice/5

Returns the shape and names after a put_slice.

## Examples

    iex> Nx.Shape.put_slice({2, 3}, [nil, :data], {1, 2}, [:batch, nil], [1, 1])
    {{2, 3}, [:batch, :data]}

    iex> Nx.Shape.put_slice({2, 3}, [nil, nil], {2, 3}, [nil, nil], [0, 1])
    {{2, 3}, [nil, nil]}

## take/5

Returns the shape and names after a take.

In practice, `axis` in `shape` gets replaced by `indices_shape`.

## Examples

    iex> Nx.Shape.take({2, 3}, [nil, :data], {10}, [nil], 0)
    {{10, 3}, [nil, :data]}

    iex> Nx.Shape.take({2, 3}, [nil, :data], {10}, [nil], 1)
    {{2, 10}, [nil, :data]}

    iex> Nx.Shape.take({2, 3}, [nil, :data], {10}, [:reordered], 0)
    {{10, 3}, [:reordered, :data]}

    iex> Nx.Shape.take({2, 3, 4}, [:x, :y, :z], {10, 20}, [:a, :b], 1)
    {{2, 10, 20, 4}, [:x, :a, :b, :z]}

## Error cases

    iex> Nx.Shape.take({2, 3}, [nil, :data], {10}, [:reordered], 1)
    ** (ArgumentError) cannot merge name :data on axis 1 with name :reordered on axis 0

## take_diagonal/1

Returns {batch_shape, matrix_shape} if valid and raises error if not.

## make_diagonal/1

Returns shape if valid and raises error if not.

## put_diagonal/3

Validates the tensor, diagonal, and offset given to `Nx.put_diagonal/3`.

## Examples

  Given a 2D tensor and a 1D diagonal:

    iex> Nx.Shape.put_diagonal({4, 4}, {4}, 0)
    :ok

    iex> Nx.Shape.put_diagonal({4, 3}, {3}, 0)
    :ok

  Given a 2D tensor and a 1D diagonal with a positive offset:

    iex> Nx.Shape.put_diagonal({4, 4}, {3}, 1)
    :ok

    iex> Nx.Shape.put_diagonal({4, 3}, {2}, 1)
    :ok

  Given a 2D tensor and a 1D diagonal with a negative offset:

    iex> Nx.Shape.put_diagonal({4, 4}, {3}, -1)
    :ok

    iex> Nx.Shape.put_diagonal({4, 3}, {3}, -1)
    :ok

## Error cases

  Given and invalid tensor:

    iex> Nx.Shape.put_diagonal({3, 3, 3}, {3}, 0)
    ** (ArgumentError) put_diagonal/3 expects tensor of rank 2, got tensor of rank: 3

  Given invalid diagonals:

    iex> Nx.Shape.put_diagonal({3, 3}, {3, 3}, 0)
    ** (ArgumentError) put_diagonal/3 expects diagonal of rank 1, got tensor of rank: 2

    iex> Nx.Shape.put_diagonal({3, 3}, {2}, 0)
    ** (ArgumentError) expected diagonal tensor of length: 3, got diagonal tensor of length: 2

    iex> Nx.Shape.put_diagonal({3, 3}, {3}, 1)
    ** (ArgumentError) expected diagonal tensor of length: 2, got diagonal tensor of length: 3

 Given invalid offsets:

    iex> Nx.Shape.put_diagonal({3, 3}, {3}, 4)
    ** (ArgumentError) offset must be less than length of axis 1 when positive, got: 4

    iex> Nx.Shape.put_diagonal({3, 3}, {3}, -3)
    ** (ArgumentError) absolute value of offset must be less than length of axis 0 when negative, got: -3

## validate_diag_offset!/2

Validates an offset to extract or create a diagonal (tensor) for given shape

## Examples

    iex> Nx.Shape.validate_diag_offset!({3, 4}, 1)
    :ok

    iex> Nx.Shape.validate_diag_offset!({3, 4}, -1)
    :ok

## Error cases

  iex> Nx.Shape.validate_diag_offset!({3, 4}, 4)
  ** (ArgumentError) offset must be less than length of axis 1 when positive, got: 4

  iex> Nx.Shape.validate_diag_offset!({3, 4}, -3)
  ** (ArgumentError) absolute value of offset must be less than length of axis 0 when negative, got: -3

  iex> Nx.Shape.validate_diag_offset!({3, 3, 3}, 0)
  ** (ArgumentError) expected shape of rank 2 to be given, got shape of rank: 3

## take_along_axis/3

Returns the shape and names after a `take_along_axis` operation is performed.

In practice, `axis` in `shape` gets replaced by `indices_shape`.

## Examples

    iex> Nx.Shape.take_along_axis({2, 3}, {10, 3}, 0)
    {10, 3}

    iex> Nx.Shape.take_along_axis({2, 3}, {2, 10}, 1)
    {2, 10}

    iex> Nx.Shape.take_along_axis({2, 3, 4}, {10, 3, 4}, 0)
    {10, 3, 4}

## Error cases

    iex> Nx.Shape.take_along_axis({2, 3, 4}, {3, 10, 4}, 1)
    ** (ArgumentError) non-indexing dimensions must match. Expected {2, *, 4}, got: {3, 10, 4}

    iex> Nx.Shape.take_along_axis({2, 3}, {1, 2, 3}, 0)
    ** (ArgumentError) shapes must have the same number of dimensions. Expected {*, 3}, got: {1, 2, 3}

## gather/3

Returns the shape after a gather.

## Examples

    iex> Nx.Shape.gather({2, 3}, {10, 2}, [0, 1])
    {{10}, [nil]}

    iex> Nx.Shape.gather({2, 3}, {4, 5, 2}, [0, 1])
    {{4, 5}, [nil, nil]}

    iex> Nx.Shape.gather({2}, {4, 5, 1}, [0])
    {{4, 5}, [nil, nil]}

    iex> Nx.Shape.gather({2, 2, 2, 2, 2}, {3, 3, 5}, [0, 1, 2, 3, 4])
    {{3, 3}, [nil, nil]}

    iex> Nx.Shape.gather({2, 2, 2}, {3}, [0, 1, 2])
    {{}, []}

    iex> Nx.Shape.gather({2, 2, 2, 2, 2}, {3, 3, 3}, [0, 1, 2])
    {{3, 3, 2, 2}, [nil, nil, nil, nil]}

## Error cases

    iex> Nx.Shape.gather({2, 3}, {}, [])
    ** (ArgumentError) expected indices rank to be at least 1, got: 0

## new_axis/6

Returns the shape and name of new axis.

## stack/5

Returns the shape and names after a stack.

## Examples

    iex> Nx.Shape.stack([{3, 2}, {3, 2}, {3, 2}], [[nil, nil], [nil, :z], [:y, nil]], 0, :x, 0)
    {{3, 3, 2}, [:x, :y, :z], 0}

## concatenate/4

Returns the shape and names after a concat.

## Examples

    iex> Nx.Shape.concatenate([{2, 3, 2}, {1, 3, 2}, {4, 3, 2}], [[:x, :y, :z], [:x, :y, :z], [:x, :y, :z]], 0, 0)
    {{7, 3, 2}, [:x, :y, :z], 0}

## tile/2

Calculates the intermediate and final shapes used by the
`Nx.tile` function.

## dot/8

Calculates the output shape of a dot product.

## cholesky/2

Returns the shape and names after a Cholesky decomposition.

## Examples

    iex> Nx.Shape.cholesky({4, 4}, [:x, :y])
    {{4, 4}, [:x, :y]}

    iex> Nx.Shape.cholesky({3, 3, 3}, [:x, :y, :z])
    {{3, 3, 3}, [:x, :y, :z]}

## Error Cases

    iex> Nx.Shape.cholesky({2, 3, 2}, [:x, :y, :z])
    ** (ArgumentError) tensor must be a square matrix or a batch of square matrices, got shape: {2, 3, 2}

    iex> Nx.Shape.cholesky({3}, [:x])
    ** (ArgumentError) tensor must have at least rank 2, got rank 1 with shape {3}

## top_k/3

Output shape after a top_k operation.

## Examples

    iex> Nx.Shape.top_k({3, 3, 3}, [:a, :b, :c], 2)
    {{3, 3, 2}, [:a, :b, :c]}

    iex> Nx.Shape.top_k({2, 3, 1}, [:a, :b, :c], 1)
    {{2, 3, 1}, [:a, :b, :c]}

## Error cases

    iex> Nx.Shape.top_k({}, [], 1)
    ** (ArgumentError) top_k input must have at least rank 1

    iex> Nx.Shape.top_k({2, 3, 1}, [:a, :b, :c], 2)
    ** (ArgumentError) top_k input last axis size must be greater than or equal to k, got size=1 and k=2

    iex> Nx.Shape.top_k({2, 3, 1}, [:a, :b, :c], -1)
    ** (ArgumentError) top_k k must be an integer greater than or equal to 1, got k=-1

## merge_names!/2

Merges names, raising on mismatch.

It assumes their length match.