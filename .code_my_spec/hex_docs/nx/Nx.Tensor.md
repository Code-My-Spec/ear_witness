# Nx.Tensor

The tensor struct and the behaviour for backends.

`Nx.Tensor` is a generic container for multidimensional data structures.
It contains the tensor type, shape, and names. The data itself is a
struct that points to a backend responsible for controlling the data.
The backend behaviour is described in `Nx.Backend`.

The tensor has the following fields:

  * `:data` - the tensor backend and its data
  * `:shape` - the tensor shape
  * `:type` - the tensor type
  * `:names` - the tensor names
  * `:vectorized_axes` - a tuple that encodes names and sizes for vectorization

In general it is discouraged to access those fields directly. Use
the functions in the `Nx` module instead. Backends have to access those
fields but it cannot update them, except for the `:data` field itself.