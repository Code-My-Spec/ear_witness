# Nx.LinAlg

Nx conveniences for linear algebra.

This module can be used in `defn`.

## cholesky/1

Performs a Cholesky decomposition of a batch of square matrices.

The matrices must be positive-definite and either Hermitian
if complex or symmetric if real. An error is raised by the
default backend if those conditions are not met. Other
backends may emit undefined behaviour.

## Examples
    iex> Nx.LinAlg.cholesky(Nx.tensor([[20.0, 17.6], [17.6, 16.0]]))
    #Nx.Tensor<
      f32[2][2]
      [
        [4.472136, 0.0],
        [3.9354796, 0.71554184]
      ]
    >

    iex> Nx.LinAlg.cholesky(Nx.tensor([[[2.0, 3.0], [3.0, 5.0]], [[1.0, 0.0], [0.0, 1.0]]]))
    #Nx.Tensor<
      f32[2][2][2]
      [
        [
          [1.4142135, 0.0],
          [2.1213205, 0.7071065]
        ],
        [
          [1.0, 0.0],
          [0.0, 1.0]
        ]
      ]
    >

    iex> t = Nx.tensor([
    ...>   [6.0, 3.0, 4.0, 8.0],
    ...>   [3.0, 6.0, 5.0, 1.0],
    ...>   [4.0, 5.0, 10.0, 7.0],
    ...>   [8.0, 1.0, 7.0, 25.0]
    ...> ])
    iex> Nx.LinAlg.cholesky(t)
    #Nx.Tensor<
      f32[4][4]
      [
        [2.4494898, 0.0, 0.0, 0.0],
        [1.2247448, 2.1213202, 0.0, 0.0],
        [1.6329931, 1.4142138, 2.309401, 0.0],
        [3.2659862, -1.4142134, 1.5877135, 3.132491]
      ]
    >

    iex> Nx.LinAlg.cholesky(Nx.tensor([[1.0, Complex.new(0, -2)], [Complex.new(0, 2), 5.0]]))
    #Nx.Tensor<
      c64[2][2]
      [
        [1.0+0.0i, 0.0+0.0i],
        [0.0+2.0i, 1.0+0.0i]
      ]
    >

    iex> t = Nx.tensor([[[2.0, 3.0], [3.0, 5.0]], [[1.0, 0.0], [0.0, 1.0]]]) |> Nx.vectorize(x: 2)
    iex> Nx.LinAlg.cholesky(t)
    #Nx.Tensor<
      vectorized[x: 2]
      f32[2][2]
      [
        [
          [1.4142135, 0.0],
          [2.1213205, 0.7071065]
        ],
        [
          [1.0, 0.0],
          [0.0, 1.0]
        ]
      ]
    >

## triangular_solve/3

Solve the equation `a x = b` for x, assuming `a` is a batch of triangular matrices.
Can also solve `x a = b` for x. See the `:left_side` option below.

`b` must either be a batch of square matrices with the same dimensions as `a` or a batch of 1-D tensors
with as many rows as `a`. Batch dimensions of `a` and `b` must be the same.

## Options

The following options are defined in order of precedence

* `:transform_a` - Defines `op(a)`, depending on its value. Can be one of:
  * `:none` -> `op(a) = a`
  * `:transpose` -> `op(a) = transpose(a)`
  Defaults to `:none`
* `:lower` - When `true`, defines the `a` matrix as lower triangular. If false, a is upper triangular.
  Defaults to `true`
* `:left_side` - When `true`, solves the system as `op(A).X = B`. Otherwise, solves `X.op(A) = B`. Defaults to `true`.

## Examples

    iex> a = Nx.tensor([[3, 0, 0, 0], [2, 1, 0, 0], [1, 0, 1, 0], [1, 1, 1, 1]])
    iex> Nx.LinAlg.triangular_solve(a, Nx.tensor([4, 2, 4, 2]))
    #Nx.Tensor<
      f32[4]
      [1.3333334, -0.6666667, 2.6666667, -1.3333334]
    >

    iex> a = Nx.tensor([[1, 0, 0], [1, 1, 0], [1, 1, 1]], type: :f64)
    iex> Nx.LinAlg.triangular_solve(a, Nx.tensor([1, 2, 1]))
    #Nx.Tensor<
      f64[3]
      [1.0, 1.0, -1.0]
    >

    iex> a = Nx.tensor([[1, 0, 0], [1, 1, 0], [0, 1, 1]])
    iex> b = Nx.tensor([[1, 2, 3], [2, 2, 4], [2, 0, 1]])
    iex> Nx.LinAlg.triangular_solve(a, b)
    #Nx.Tensor<
      f32[3][3]
      [
        [1.0, 2.0, 3.0],
        [1.0, 0.0, 1.0],
        [1.0, 0.0, 0.0]
      ]
    >

    iex> a = Nx.tensor([[1, 1, 1, 1], [0, 1, 0, 1], [0, 0, 1, 2], [0, 0, 0, 3]])
    iex> Nx.LinAlg.triangular_solve(a, Nx.tensor([2, 4, 2, 4]), lower: false)
    #Nx.Tensor<
      f32[4]
      [-1.3333334, 2.6666667, -0.6666667, 1.3333334]
    >

    iex> a = Nx.tensor([[1, 0, 0], [1, 1, 0], [1, 2, 1]])
    iex> b = Nx.tensor([[0, 2, 1], [1, 1, 0], [3, 3, 1]])
    iex> Nx.LinAlg.triangular_solve(a, b, left_side: false)
    #Nx.Tensor<
      f32[3][3]
      [
        [-1.0, 0.0, 1.0],
        [0.0, 1.0, 0.0],
        [1.0, 1.0, 1.0]
      ]
    >

    iex> a = Nx.tensor([[1, 1, 1], [0, 1, 1], [0, 0, 1]], type: :f64)
    iex> Nx.LinAlg.triangular_solve(a, Nx.tensor([1, 2, 1]), transform_a: :transpose, lower: false)
    #Nx.Tensor<
      f64[3]
      [1.0, 1.0, -1.0]
    >

    iex> a = Nx.tensor([[1, 0, 0], [1, 1, 0], [1, 1, 1]], type: :f64)
    iex> Nx.LinAlg.triangular_solve(a, Nx.tensor([1, 2, 1]), transform_a: :none)
    #Nx.Tensor<
      f64[3]
      [1.0, 1.0, -1.0]
    >

    iex> a = Nx.tensor([[1, 0, 0], [1, 1, 0], [1, 2, 1]])
    iex> b = Nx.tensor([[0, 1, 3], [2, 1, 3]])
    iex> Nx.LinAlg.triangular_solve(a, b, left_side: false)
    #Nx.Tensor<
      f32[2][3]
      [
        [2.0, -5.0, 3.0],
        [4.0, -5.0, 3.0]
      ]
    >

    iex> a = Nx.tensor([[1, 0, 0], [1, 1, 0], [1, 2, 1]])
    iex> b = Nx.tensor([[0, 2], [3, 0], [0, 0]])
    iex> Nx.LinAlg.triangular_solve(a, b, left_side: true)
    #Nx.Tensor<
      f32[3][2]
      [
        [0.0, 2.0],
        [3.0, -2.0],
        [-6.0, 2.0]
      ]
    >

    iex> a = Nx.tensor([
    ...> [1, 0, 0],
    ...> [1, Complex.new(0, 1), 0],
    ...> [Complex.new(0, 1), 1, 1]
    ...>])
    iex> b = Nx.tensor([1, -1, Complex.new(3, 3)])
    iex> Nx.LinAlg.triangular_solve(a, b)
    #Nx.Tensor<
      c64[3]
      [1.0+0.0i, 0.0+2.0i, 3.0+0.0i]
    >

    iex> a = Nx.tensor([[[1, 0], [2, 3]], [[4, 0], [5, 6]]])
    iex> b = Nx.tensor([[2, -1], [3, 7]])
    iex> Nx.LinAlg.triangular_solve(a, b)
    #Nx.Tensor<
      f32[2][2]
      [
        [2.0, -1.6666666],
        [0.75, 0.5416667]
      ]
    >

    iex> a = Nx.tensor([[[1, 1], [0, 1]], [[2, 0], [0, 2]]]) |> Nx.vectorize(x: 2)
    iex> b = Nx.tensor([[[2, 1], [5, -1]]]) |> Nx.vectorize(x: 1, y: 2)
    iex> Nx.LinAlg.triangular_solve(a, b, lower: false)
    #Nx.Tensor<
      vectorized[x: 2][y: 2]
      f32[2]
      [
        [
          [1.0, 1.0],
          [6.0, -1.0]
        ],
        [
          [1.0, 0.5],
          [2.5, -0.5]
        ]
      ]
    >

## Error cases

    iex> Nx.LinAlg.triangular_solve(Nx.tensor([[3, 0, 0, 0], [2, 1, 0, 0]]), Nx.tensor([4, 2, 4, 2]))
    ** (ArgumentError) triangular_solve/3 expected a square matrix or a batch of square matrices, got tensor with shape: {2, 4}

    iex> Nx.LinAlg.triangular_solve(Nx.tensor([[3, 0, 0, 0], [2, 1, 0, 0], [1, 1, 1, 1], [1, 1, 1, 1]]), Nx.tensor([4]))
    ** (ArgumentError) incompatible dimensions for a and b on triangular solve

    iex> Nx.LinAlg.triangular_solve(Nx.tensor([[0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], [1, 1, 1, 1]]), Nx.tensor([4, 2, 4, 2]))
    ** (ArgumentError) can't solve for singular matrix

    iex> a = Nx.tensor([[1, 0, 0], [1, 1, 0], [1, 1, 1]], type: :f64)
    iex> Nx.LinAlg.triangular_solve(a, Nx.tensor([1, 2, 1]), transform_a: :conjugate)
    #Nx.Tensor<
      f64[3]
      [1.0, 1.0, -1.0]
    >

    iex> a = Nx.tensor([[1, 0, 0], [1, 1, 0], [1, 1, 1]], type: :f64)
    iex> Nx.LinAlg.triangular_solve(a, Nx.tensor([1, 2, 1]), transform_a: :other)
    ** (ArgumentError) invalid value for :transform_a option, expected :none, :transpose, or :conjugate, got: :other

## solve/2

Solves the system `AX = B`.

`A` must have shape `{..., n, n}` and `B` must have shape `{..., n, m}` or `{..., n}`.
`X` has the same shape as `B`.

## Examples

    iex> a = Nx.tensor([[1, 3, 2, 1], [2, 1, 0, 0], [1, 0, 1, 0], [1, 1, 1, 1]])
    iex> Nx.LinAlg.solve(a, Nx.tensor([-3, 0, 4, -2]))
    #Nx.Tensor<
      f32[4]
      [1.0, -2.0, 3.0000002, -4.0]
    >

    iex> a = Nx.tensor([[1, 0, 1], [1, 1, 0], [1, 1, 1]], type: :f64)
    iex> Nx.LinAlg.solve(a, Nx.tensor([0, 2, 1]))
    #Nx.Tensor<
      f64[3]
      [1.0, 1.0, -1.0]
    >

    iex> a = Nx.tensor([[1, 0, 1], [1, 1, 0], [0, 1, 1]])
    iex> b = Nx.tensor([[2, 2, 3], [2, 2, 4], [2, 0, 1]])
    iex> Nx.LinAlg.solve(a, b)
    #Nx.Tensor<
      f32[3][3]
      [
        [1.0, 2.0, 3.0],
        [1.0, 0.0, 1.0],
        [1.0, 0.0, 0.0]
      ]
    >

    iex> a = Nx.tensor([[[14, 10], [9, 9]], [[4, 11], [2, 3]]])
    iex> b = Nx.tensor([[[2, 4], [3, 2]], [[1, 5], [-3, -1]]])
    iex> Nx.LinAlg.solve(a, b)
    #Nx.Tensor<
      f32[2][2][2]
      [
        [
          [-0.3333333, 0.44444442],
          [0.6666666, -0.2222222]
        ],
        [
          [-3.6, -2.6],
          [1.4, 1.4]
        ]
      ]
    >

    iex> a = Nx.tensor([[[1, 1], [0, 1]], [[2, 0], [0, 2]]]) |> Nx.vectorize(x: 2)
    iex> b = Nx.tensor([[[2, 1], [5, -1]]]) |> Nx.vectorize(x: 1, y: 2)
    iex> Nx.LinAlg.solve(a, b)
    #Nx.Tensor<
      vectorized[x: 2][y: 2]
      f32[2]
      [
        [
          [1.0, 1.0],
          [6.0, -1.0]
        ],
        [
          [1.0, 0.5],
          [2.5, -0.5]
        ]
      ]
    >

If the axes are named, their names are not preserved in the output:

    iex> a = Nx.tensor([[1, 0, 1], [1, 1, 0], [1, 1, 1]], names: [:x, :y])
    iex> Nx.LinAlg.solve(a, Nx.tensor([0, 2, 1], names: [:z]))
    #Nx.Tensor<
      f32[3]
      [1.0, 1.0, -1.0]
    >

## Error cases

    iex> Nx.LinAlg.solve(Nx.tensor([[1, 0], [0, 1]]), Nx.tensor([4, 2, 4, 2]))
    ** (ArgumentError) `b` tensor has incompatible dimensions, expected {2, 2} or {2}, got: {4}

    iex> Nx.LinAlg.solve(Nx.tensor([[3, 0, 0, 0], [2, 1, 0, 0], [1, 1, 1, 1]]), Nx.tensor([4]))
    ** (ArgumentError) `a` tensor has incompatible dimensions, expected a square matrix or a batch of square matrices, got: {3, 4}

## qr/2

Calculates the QR decomposition of a tensor with shape `{..., M, N}`.

## Options

  * `:mode` - Can be one of `:reduced`, `:complete`. Defaults to `:reduced`
    For the following, `K = min(M, N)`

    * `:reduced` - returns `q` and `r` with shapes `{..., M, K}` and `{..., K, N}`
    * `:complete` - returns `q` and `r` with shapes `{..., M, M}` and `{..., M, N}`

  * `:eps` - Rounding error threshold that can be applied during the triangularization. Defaults to `1.0e-10`

## Examples

    iex> {q, r} = Nx.LinAlg.qr(Nx.tensor([[-3, 2, 1], [0, 1, 1], [0, 0, -1]]))
    iex> q
    #Nx.Tensor<
      f32[3][3]
      [
        [1.0, 0.0, 0.0],
        [0.0, 1.0, 0.0],
        [0.0, 0.0, 1.0]
      ]
    >
    iex> r
    #Nx.Tensor<
      f32[3][3]
      [
        [-3.0, 2.0, 1.0],
        [0.0, 1.0, 1.0],
        [0.0, 0.0, -1.0]
      ]
    >

    iex> t = Nx.tensor([[3, 2, 1], [0, 1, 1], [0, 0, 1]])
    iex> {q, r} = Nx.LinAlg.qr(t)
    iex> q
    #Nx.Tensor<
      f32[3][3]
      [
        [1.0, 0.0, 0.0],
        [0.0, 1.0, 0.0],
        [0.0, 0.0, 1.0]
      ]
    >
    iex> r
    #Nx.Tensor<
      f32[3][3]
      [
        [3.0, 2.0, 1.0],
        [0.0, 1.0, 1.0],
        [0.0, 0.0, 1.0]
      ]
    >

    iex> {qs, rs} = Nx.LinAlg.qr(Nx.tensor([[[-3, 2, 1], [0, 1, 1], [0, 0, -1]],[[3, 2, 1], [0, 1, 1], [0, 0, 1]]]))
    iex> qs
    #Nx.Tensor<
      f32[2][3][3]
      [
        [
          [1.0, 0.0, 0.0],
          [0.0, 1.0, 0.0],
          [0.0, 0.0, 1.0]
        ],
        [
          [1.0, 0.0, 0.0],
          [0.0, 1.0, 0.0],
          [0.0, 0.0, 1.0]
        ]
      ]
    >
    iex> rs
    #Nx.Tensor<
      f32[2][3][3]
      [
        [
          [-3.0, 2.0, 1.0],
          [0.0, 1.0, 1.0],
          [0.0, 0.0, -1.0]
        ],
        [
          [3.0, 2.0, 1.0],
          [0.0, 1.0, 1.0],
          [0.0, 0.0, 1.0]
        ]
      ]
    >

    iex> t = Nx.tensor([[3, 2, 1], [0, 1, 1], [0, 0, 1], [0, 0, 1]], type: :f32)
    iex> {q, r} = Nx.LinAlg.qr(t, mode: :reduced)
    iex> q
    #Nx.Tensor<
      f32[4][3]
      [
        [1.0, 0.0, 0.0],
        [0.0, 1.0, 0.0],
        [0.0, 0.0, 0.7071068],
        [0.0, 0.0, 0.70710677]
      ]
    >
    iex> r
    #Nx.Tensor<
      f32[3][3]
      [
        [3.0, 2.0, 1.0],
        [0.0, 1.0, 1.0],
        [0.0, 0.0, 1.4142137]
      ]
    >

    iex> t = Nx.tensor([[3, 2, 1], [0, 1, 1], [0, 0, 1], [0, 0, 0]], type: :f32)
    iex> {q, r} = Nx.LinAlg.qr(t, mode: :complete)
    iex> q
    #Nx.Tensor<
      f32[4][4]
      [
        [1.0, 0.0, 0.0, 0.0],
        [0.0, 1.0, 0.0, 0.0],
        [0.0, 0.0, 1.0, 0.0],
        [0.0, 0.0, 0.0, 1.0]
      ]
    >
    iex> r
    #Nx.Tensor<
      f32[4][3]
      [
        [3.0, 2.0, 1.0],
        [0.0, 1.0, 1.0],
        [0.0, 0.0, 1.0],
        [0.0, 0.0, 0.0]
      ]
    >

    iex> t = Nx.tensor([[[-3, 2, 1], [0, 1, 1], [0, 0, -1]],[[3, 2, 1], [0, 1, 1], [0, 0, 1]]]) |> Nx.vectorize(x: 2)
    iex> {qs, rs} = Nx.LinAlg.qr(t)
    iex> qs
    #Nx.Tensor<
      vectorized[x: 2]
      f32[3][3]
      [
        [
          [1.0, 0.0, 0.0],
          [0.0, 1.0, 0.0],
          [0.0, 0.0, 1.0]
        ],
        [
          [1.0, 0.0, 0.0],
          [0.0, 1.0, 0.0],
          [0.0, 0.0, 1.0]
        ]
      ]
    >
    iex> rs
    #Nx.Tensor<
      vectorized[x: 2]
      f32[3][3]
      [
        [
          [-3.0, 2.0, 1.0],
          [0.0, 1.0, 1.0],
          [0.0, 0.0, -1.0]
        ],
        [
          [3.0, 2.0, 1.0],
          [0.0, 1.0, 1.0],
          [0.0, 0.0, 1.0]
        ]
      ]
    >

## Error cases

    iex> Nx.LinAlg.qr(Nx.tensor([1, 2, 3, 4, 5]))
    ** (ArgumentError) tensor must have at least rank 2, got rank 1 with shape {5}

    iex> t = Nx.tensor([[-3, 2, 1], [0, 1, 1], [0, 0, -1]])
    iex> Nx.LinAlg.qr(t, mode: :error_test)
    ** (ArgumentError) invalid :mode received. Expected one of [:reduced, :complete], received: :error_test

## eigh/2

Calculates the Eigenvalues and Eigenvectors of batched Hermitian 2-D matrices.

It returns `{eigenvals, eigenvecs}`.

## Options

  * `:max_iter` - `integer`. Defaults to `1_000`
    Number of maximum iterations before stopping the decomposition

  * `:eps` - `float`. Defaults to 1.0e-4
    Tolerance applied during the decomposition

Note not all options apply to all backends, as backends may have
specific optimizations that render these mechanisms unnecessary.

## Examples

    iex> {eigenvals, eigenvecs} = Nx.LinAlg.eigh(Nx.tensor([[1, 0], [0, 2]]))
    iex> Nx.round(eigenvals)
    #Nx.Tensor<
      f32[2]
      [2.0, 1.0]
    >
    iex> eigenvecs
    #Nx.Tensor<
      f32[2][2]
      [
        [0.0, 1.0],
        [1.0, 0.0]
      ]
    >

    iex> {eigenvals, eigenvecs} = Nx.LinAlg.eigh(Nx.tensor([[0, 1, 2], [1, 0, 2], [2, 2, 3]]))
    iex> Nx.round(eigenvals)
    #Nx.Tensor<
      f32[3]
      [5.0, -1.0, -1.0]
    >
    iex> eigenvecs
    #Nx.Tensor<
      f32[3][3]
      [
        [0.40824828, -0.1825742, 0.8944272],
        [0.40824834, 0.9128709, 0.0],
        [0.81649655, -0.3651484, -0.4472136]
      ]
    >

    iex> {eigenvals, eigenvecs} = Nx.LinAlg.eigh(Nx.tensor([[[2, 5],[5, 6]], [[1, 0], [0, 4]]]))
    iex> Nx.round(eigenvals)
    #Nx.Tensor<
      f32[2][2]
      [
        [9.0, -1.0],
        [4.0, 1.0]
      ]
    >
    iex> eigenvecs
    #Nx.Tensor<
      f32[2][2][2]
      [
        [
          [0.56062883, 0.8280672],
          [0.8280672, -0.56062883]
        ],
        [
          [0.0, 1.0],
          [1.0, 0.0]
        ]
      ]
    >

    iex> t = Nx.tensor([[[2, 5],[5, 6]], [[1, 0], [0, 4]]]) |> Nx.vectorize(x: 2)
    iex> {eigenvals, eigenvecs} = Nx.LinAlg.eigh(t)
    iex> Nx.round(eigenvals)
    #Nx.Tensor<
      vectorized[x: 2]
      f32[2]
      [
        [9.0, -1.0],
        [4.0, 1.0]
      ]
    >
    iex> eigenvecs
    #Nx.Tensor<
      vectorized[x: 2]
      f32[2][2]
      [
        [
          [0.56062883, 0.8280672],
          [0.8280672, -0.56062883]
        ],
        [
          [0.0, 1.0],
          [1.0, 0.0]
        ]
      ]
    >

## Error cases

    iex> Nx.LinAlg.eigh(Nx.tensor([[1, 2, 3], [4, 5, 6]]))
    ** (ArgumentError) tensor must be a square matrix or a batch of square matrices, got shape: {2, 3}

## svd/2

Calculates the Singular Value Decomposition of batched 2-D matrices.

It returns `{u, s, vt}` where the elements of `s` are sorted
from highest to lowest.

## Options

  * `:max_iter` - `integer`. Defaults to `100`
    Number of maximum iterations before stopping the decomposition

  * `:full_matrices?` - `boolean`. Defaults to `true`
    If `true`, `u` and `vt` are of shape (M, M), (N, N). Otherwise,
    the shapes are (M, K) and (K, N), where K = min(M, N).

Note not all options apply to all backends, as backends may have
specific optimizations that render these mechanisms unnecessary.

## Examples

    iex> {u, s, vt} = Nx.LinAlg.svd(Nx.tensor([[1, 0, 0], [0, 1, 0], [0, 0, -1]]))
    iex> u
    #Nx.Tensor<
      f32[3][3]
      [
        [1.0, 0.0, 0.0],
        [0.0, 1.0, 0.0],
        [0.0, 0.0, -1.0]
      ]
    >
    iex> s
    #Nx.Tensor<
      f32[3]
      [1.0, 1.0, 1.0]
    >
    iex> vt
    #Nx.Tensor<
      f32[3][3]
      [
        [1.0, 0.0, 0.0],
        [0.0, 1.0, 0.0],
        [0.0, 0.0, 1.0]
      ]
    >

    iex> {u, s, vt} = Nx.LinAlg.svd(Nx.tensor([[2, 0, 0], [0, 3, 0], [0, 0, -1], [0, 0, 0]]))
    iex> u
    #Nx.Tensor<
      f32[4][4]
      [
        [0.0, 0.99999994, 0.0, 0.0],
        [1.0, 0.0, 0.0, 0.0],
        [0.0, 0.0, -1.0, 0.0],
        [0.0, 0.0, 0.0, 1.0]
      ]
    >
    iex> s
    #Nx.Tensor<
      f32[3]
      [3.0, 1.9999999, 1.0]
    >
    iex> vt
    #Nx.Tensor<
      f32[3][3]
      [
        [0.0, 1.0, 0.0],
        [1.0, 0.0, 0.0],
        [0.0, 0.0, 1.0]
      ]
    >

    iex> {u, s, vt} = Nx.LinAlg.svd(Nx.tensor([[2, 0, 0], [0, 3, 0], [0, 0, -1], [0, 0, 0]]), full_matrices?: false)
    iex> u
    #Nx.Tensor<
      f32[4][3]
      [
        [0.0, 1.0, 0.0],
        [1.0, 0.0, 0.0],
        [0.0, 0.0, -1.0],
        [0.0, 0.0, 0.0]
      ]
    >
    iex> s
    #Nx.Tensor<
      f32[3]
      [3.0, 2.0, 1.0]
    >
    iex> vt
    #Nx.Tensor<
      f32[3][3]
      [
        [0.0, 1.0, 0.0],
        [1.0, 0.0, 0.0],
        [0.0, 0.0, 1.0]
      ]
    >

## lu/1

Calculates the A = PLU decomposition of batched square 2-D matrices A.

## Examples

    iex> {p, l, u} = Nx.LinAlg.lu(Nx.tensor([[1, 2, 3], [4, 5, 6], [7, 8, 9]]))
    iex> p
    #Nx.Tensor<
      s32[3][3]
      [
        [0, 1, 0],
        [0, 0, 1],
        [1, 0, 0]
      ]
    >
    iex> l
    #Nx.Tensor<
      f32[3][3]
      [
        [1.0, 0.0, 0.0],
        [0.14285715, 1.0, 0.0],
        [0.5714286, 0.4999998, 1.0]
      ]
    >
    iex> u
    #Nx.Tensor<
      f32[3][3]
      [
        [7.0, 8.0, 9.0],
        [0.0, 0.8571428, 1.7142856],
        [0.0, 0.0, 0.0]
      ]
    >
    iex> p |> Nx.dot(l) |> Nx.dot(u)
    #Nx.Tensor<
      f32[3][3]
      [
        [1.0, 2.0, 3.0],
        [4.0, 5.0, 6.0],
        [7.0, 8.0, 9.0]
      ]
    >

    iex> {p, l, u} = Nx.LinAlg.lu(Nx.tensor([[1, 0, 1], [-1, 0, -1], [1, 1, 1]]))
    iex> p
    #Nx.Tensor<
      s32[3][3]
      [
        [1, 0, 0],
        [0, 0, 1],
        [0, 1, 0]
      ]
    >
    iex> l
    #Nx.Tensor<
      f32[3][3]
      [
        [1.0, 0.0, 0.0],
        [1.0, 1.0, 0.0],
        [-1.0, 0.0, 1.0]
      ]
    >
    iex> u
    #Nx.Tensor<
      f32[3][3]
      [
        [1.0, 0.0, 1.0],
        [0.0, 1.0, 0.0],
        [0.0, 0.0, 0.0]
      ]
    >
    iex> p |> Nx.dot(l) |> Nx.dot(u)
    #Nx.Tensor<
      f32[3][3]
      [
        [1.0, 0.0, 1.0],
        [-1.0, 0.0, -1.0],
        [1.0, 1.0, 1.0]
      ]
    >

    iex> {p, l, u} = Nx.LinAlg.lu(Nx.tensor([[[9, 8, 7], [6, 5, 4], [3, 2, 1]], [[-1, 0, -1], [1, 0, 1], [1, 1, 1]]]))
    iex> p
    #Nx.Tensor<
      s32[2][3][3]
      [
        [
          [1, 0, 0],
          [0, 0, 1],
          [0, 1, 0]
        ],
        [
          [1, 0, 0],
          [0, 0, 1],
          [0, 1, 0]
        ]
      ]
    >
    iex> l
    #Nx.Tensor<
      f32[2][3][3]
      [
        [
          [1.0, 0.0, 0.0],
          [0.33333334, 1.0, 0.0],
          [0.6666667, 0.5000002, 1.0]
        ],
        [
          [1.0, 0.0, 0.0],
          [-1.0, 1.0, 0.0],
          [-1.0, 0.0, 1.0]
        ]
      ]
    >
    iex> u
    #Nx.Tensor<
      f32[2][3][3]
      [
        [
          [9.0, 8.0, 7.0],
          [0.0, -0.66666675, -1.3333335],
          [0.0, 0.0, 0.0]
        ],
        [
          [-1.0, 0.0, -1.0],
          [0.0, 1.0, 0.0],
          [0.0, 0.0, 0.0]
        ]
      ]
    >
    iex> p |> Nx.dot([2], [0], l, [1], [0]) |> Nx.dot([2], [0], u, [1], [0])
    #Nx.Tensor<
      f32[2][3][3]
      [
        [
          [9.0, 8.0, 7.0],
          [6.0, 5.0, 3.9999998],
          [3.0, 2.0, 0.9999999]
        ],
        [
          [-1.0, 0.0, -1.0],
          [1.0, 0.0, 1.0],
          [1.0, 1.0, 1.0]
        ]
      ]
    >

    iex> t = Nx.tensor([[[9, 8, 7], [6, 5, 4], [3, 2, 1]], [[-1, 0, -1], [1, 0, 1], [1, 1, 1]]]) |> Nx.vectorize(x: 2)
    iex> {p, l, u} = Nx.LinAlg.lu(t)
    iex> p
    #Nx.Tensor<
      vectorized[x: 2]
      s32[3][3]
      [
        [
          [1, 0, 0],
          [0, 0, 1],
          [0, 1, 0]
        ],
        [
          [1, 0, 0],
          [0, 0, 1],
          [0, 1, 0]
        ]
      ]
    >
    iex> l
    #Nx.Tensor<
      vectorized[x: 2]
      f32[3][3]
      [
        [
          [1.0, 0.0, 0.0],
          [0.33333334, 1.0, 0.0],
          [0.6666667, 0.5000002, 1.0]
        ],
        [
          [1.0, 0.0, 0.0],
          [-1.0, 1.0, 0.0],
          [-1.0, 0.0, 1.0]
        ]
      ]
    >
    iex> u
    #Nx.Tensor<
      vectorized[x: 2]
      f32[3][3]
      [
        [
          [9.0, 8.0, 7.0],
          [0.0, -0.66666675, -1.3333335],
          [0.0, 0.0, 0.0]
        ],
        [
          [-1.0, 0.0, -1.0],
          [0.0, 1.0, 0.0],
          [0.0, 0.0, 0.0]
        ]
      ]
    >

## Error cases

    iex> Nx.LinAlg.lu(Nx.tensor([[1, 1, 1, 1], [-1, 4, 4, -1], [4, -2, 2, 0]]))
    ** (ArgumentError) tensor must be a square matrix or a batch of square matrices, got shape: {3, 4}

## matrix_power/2

Produces the tensor taken to the given power by matrix dot-product.

The input is always a tensor of batched square matrices and an integer,
and the output is a tensor of the same dimensions as the input tensor.

The dot-products are unrolled inside `defn`.

## Examples

    iex> Nx.LinAlg.matrix_power(Nx.tensor([[1, 2], [3, 4]]), 0)
    #Nx.Tensor<
      s32[2][2]
      [
        [1, 0],
        [0, 1]
      ]
    >

    iex> Nx.LinAlg.matrix_power(Nx.tensor([[1, 2], [3, 4]]), 6)
    #Nx.Tensor<
      s32[2][2]
      [
        [5743, 8370],
        [12555, 18298]
      ]
    >

    iex> Nx.LinAlg.matrix_power(Nx.eye(3), 65535)
    #Nx.Tensor<
      s32[3][3]
      [
        [1, 0, 0],
        [0, 1, 0],
        [0, 0, 1]
      ]
    >

    iex> Nx.LinAlg.matrix_power(Nx.tensor([[1, 2], [3, 4]]), -1)
    #Nx.Tensor<
      f32[2][2]
      [
        [-2.0000002, 1.0000001],
        [1.5000001, -0.50000006]
      ]
    >

    iex> Nx.LinAlg.matrix_power(Nx.iota({2, 2, 2}), 3)
    #Nx.Tensor<
      s32[2][2][2]
      [
        [
          [6, 11],
          [22, 39]
        ],
        [
          [514, 615],
          [738, 883]
        ]
      ]
    >

    iex> Nx.LinAlg.matrix_power(Nx.iota({2, 2, 2}), -3)
    #Nx.Tensor<
      f32[2][2][2]
      [
        [
          [-4.875, 1.375],
          [2.75, -0.75]
        ],
        [
          [-110.37471, 76.87479],
          [92.24976, -64.24983]
        ]
      ]
    >

    iex> Nx.LinAlg.matrix_power(Nx.tensor([[1, 2], [3, 4], [5, 6]]), 1)
    ** (ArgumentError) matrix_power/2 expects a square matrix or a batch of square matrices, got tensor with shape: {3, 2}

## determinant/1

Calculates the determinant of batched square matrices.

## Examples

For 2x2 and 3x3, the results are given by the closed formulas:

    iex> Nx.LinAlg.determinant(Nx.tensor([[1, 2], [3, 4]]))
    #Nx.Tensor<
      f32
      -2.0
    >

    iex> Nx.LinAlg.determinant(Nx.tensor([[1.0, 2.0, 3.0], [1.0, -2.0, 3.0], [7.0, 8.0, 9.0]]))
    #Nx.Tensor<
      f32
      48.0
    >

When there are linearly dependent rows or columns, the determinant is 0:

    iex> Nx.LinAlg.determinant(Nx.tensor([[1.0, 0.0], [3.0, 0.0]]))
    #Nx.Tensor<
      f32
      0.0
    >

    iex> Nx.LinAlg.determinant(Nx.tensor([[1.0, 2.0, 3.0], [-1.0, -2.0, -3.0], [4.0, 5.0, 6.0]]))
    #Nx.Tensor<
      f32
      0.0
    >

The determinant can also be calculated when the axes are bigger than 3:

    iex> Nx.LinAlg.determinant(Nx.tensor([
    ...> [1, 0, 0, 0],
    ...> [0, 1, 2, 3],
    ...> [0, 1, -2, 3],
    ...> [0, 7, 8, 9.0]
    ...> ]))
    #Nx.Tensor<
      f32
      47.999996
    >

    iex> Nx.LinAlg.determinant(Nx.tensor([
    ...> [0, 0, 0, 0, -1],
    ...> [0, 1, 2, 3, 0],
    ...> [0, 1, -2, 3, 0],
    ...> [0, 7, 8, 9, 0],
    ...> [1, 0, 0, 0, 0]
    ...> ]))
    #Nx.Tensor<
      f32
      47.999996
    >

    iex> Nx.LinAlg.determinant(Nx.tensor([
    ...> [[2, 4, 6, 7], [5, 1, 8, 8], [1, 7, 3, 1], [3, 9, 2, 4]],
    ...> [[2, 5, 1, 3], [4, 1, 7, 9], [6, 8, 3, 2], [7, 8, 1, 4]]
    ...> ]))
    #Nx.Tensor<
      f32[2]
      [630.0, 630.00006]
    >

    iex> t = Nx.tensor([[[1, 0], [0, 2]], [[3, 0], [0, 4]]]) |> Nx.vectorize(x: 2)
    iex> Nx.LinAlg.determinant(t)
    #Nx.Tensor<
      vectorized[x: 2]
      f32
      [2.0, 12.0]
    >

If the axes are named, their names are not preserved in the output:

    iex> two_by_two = Nx.tensor([[1, 2], [3, 4]], names: [:x, :y])
    iex> Nx.LinAlg.determinant(two_by_two)
    #Nx.Tensor<
      f32
      -2.0
    >

    iex> three_by_three = Nx.tensor([[1.0, 2.0, 3.0], [1.0, -2.0, 3.0], [7.0, 8.0, 9.0]], names: [:x, :y])
    iex> Nx.LinAlg.determinant(three_by_three)
    #Nx.Tensor<
      f32
      48.0
    >

Also supports complex inputs:

    iex> t = Nx.tensor([[1, 0, 0], [0, Complex.new(0, 2), 0], [0, 0, 3]])
    iex> Nx.LinAlg.determinant(t)
    #Nx.Tensor<
      c64
      0.0+6.0i
    >

    iex> t = Nx.tensor([[0, 0, 0, 1], [0, Complex.new(0, 2), 0, 0], [0, 0, 3, 0], [1, 0, 0, 0]])
    iex> Nx.LinAlg.determinant(t)
    #Nx.Tensor<
      c64
      -0.0-6.0i
    >