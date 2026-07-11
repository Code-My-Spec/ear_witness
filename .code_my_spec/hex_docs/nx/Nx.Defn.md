# Nx.Defn



## default_options/1

Sets the default options for `defn` in the current process.

The options defined here apply to all future invocations of
`defn` done by the current process. It also applies to calls
to the `jit/3` and `stream/3` functions in this module.

The default options are stored only in the process dictionary
and override any global options. This means if you start a
separate process, such as `Task`, the default options must be
set on the new process too.

The function returns the values that were previously set as default
options.

This function must be used only for scripting and testing.

## Examples

    iex> Nx.Defn.default_options(compiler: EXLA, client: :cuda)
    iex> Nx.Defn.default_options()
    [compiler: EXLA, client: :cuda]

## default_options/0

Gets the default options for the current process.

## to_backend/1

Returns a backend corresponding to the compiler options.

The backend matches the backend used for outputs from computations
defined by the given compiler.

## compile/3

Compiles the given anonymous function with the given tensor shapes.

While `jit/2` compiles a function just-in time based on the
input shapes, this function precompiles the given anonymous
function based on the input shapes. This can be beneficial for
large numerical definitions, where the cache mechanism in `jit/2`
may take milliseconds.

For example, take the following definition:

    defn softmax(t), do: Nx.exp(t) / Nx.sum(Nx.exp(t))

You can jit and then apply it as:

    fun = Nx.Defn.compile(&softmax/1, [Nx.template({3}, {:s, 32})], compiler: EXLA)
    fun.(Nx.tensor([1, 2, 3]))

You can also pass a mixture of templates and options when
compiling a function. In such cases, you must only pass
the inputs when invoking the compiled function, as the options
will already be embedded in its compiled value:

    fun = Nx.Defn.compile(&Nx.sum/2, [Nx.template({2, 2}, {:s, 32}), [axes: [1]]])
    fun.(Nx.iota({2, 2}))

If the input tensors do not match the shape of the tensors
given on compilation, it will raise.

## Options

  * `:compiler` - the compiler for the JIT compilation

  * `:hooks` - a map of hooks to execute. See `Nx.Defn.Kernel.hook/3`

## jit/2

Wraps an anonymous function with just-in-time compilation.

Once invoked, the wrapped anonymous function will perform just
in time compilation with the configured compiler. For example,
take the following definition:

    defn softmax(t), do: Nx.exp(t) / Nx.sum(Nx.exp(t))

You can jit and then apply it as:

    fun = Nx.Defn.jit(&softmax/1, compiler: EXLA)
    fun.(Nx.tensor([1, 2, 3]))

## Options

  * `:compiler` - the compiler for the JIT compilation

  * `:hooks` - a map of hooks to execute. See `Nx.Defn.Kernel.hook/3`

  * `:on_conflict` - what to do if a JIT compilation is already in place.
    It may be `:raise` (the default), `:force` (forces a new JIT compilation),
    or `:reuse` (reuses the exiting JIT compilation). It is not recommended
    to set the `:compiler` option when reusing.

## jit_apply/3

Invokes the anonymous function with just-in-time compilation.

This function is equivalent to calling `jit/2` and then applying
the given arguments to the anonymous function.

For example, take the following definition:

    defn softmax(t), do: Nx.exp(t) / Nx.sum(Nx.exp(t))

You can `jit_apply/3` it as:

    Nx.Defn.jit_apply(&softmax/1, [Nx.tensor([1, 2, 3])], compiler: EXLA)

It accepts the same options as `jit/2`.

## debug_expr/2

Wraps an anonymous function to return its underlying defn expression.

> #### Warning {: .warning}
>
> This function must be invoked for debugging purposes only.

## Options

  * `:hooks` - a map of hooks to execute. See `Nx.Defn.Kernel.hook/3`

## debug_expr_apply/3

Invokes the anonymous function to return its underlying defn expression.

> #### Warning {: .warning}
>
> This function must be invoked for debugging purposes only.

It accepts the same options as `debug_expr/2`.

## grad/1

Receives an anonymous function and returns a new anonymous function
that returns the gradient of the input function when invoked.

## Examples

    iex> fun = Nx.Defn.grad(fn x -> Nx.sin(x) end)
    iex> fun.(Nx.tensor(0))
    #Nx.Tensor<
      f32
      1.0
    >

## grad/2

Computes the gradient of the given `var` on `fun`.

The result of the `grad` function must be a scalar tensor.
If a non-scalar tensor is given, it is assumed the additional
dimensions are batch dimensions.

## Examples

    defn tanh_grad(t) do
      grad(t, &Nx.tanh/1)
    end

To differentiate on multiple vars, pass a tuple as first argument:

    defn tanh_power_grad(a, b) do
      grad({a, b}, fn {a, b} -> Nx.tanh(a) + Nx.pow(b, 2) end)
    end

`var_or_vars` can be any `Nx.Container` with one or multiple
tensors.

## value_and_grad/1

Receives an anonymous function and returns a new anonymous function
that returns the value and gradient of the input function when invoked.

## Examples

    iex> fun = Nx.Defn.value_and_grad(fn x -> Nx.sin(x) end)
    iex> {value, grad} = fun.(Nx.tensor(0))
    iex> value
    #Nx.Tensor<
      f32
      0.0
    >
    iex> grad
    #Nx.Tensor<
      f32
      1.0
    >

## value_and_grad/3

Computes the value and gradient of the given `var` on `fun`
with an optional data transformation.

It returns a tuple with the value and the gradient.

## Examples

    defn tanh_grad(t) do
      value_and_grad(t, &Nx.tanh/1)
    end

To differentiate on multiple vars, pass a tuple as first argument:

    defn tanh_power_grad(a, b) do
      value_and_grad({a, b}, fn {a, b} -> Nx.tanh(a) + Nx.pow(b, 2) end)
    end

`var_or_vars` can be any `Nx.Container` with one or multiple
tensors.

`transform` allows you to transform the expression before the gradient is
calculated. This enables optimizations that reuse parts of expressions. As
an example, consider the following objective function:

    defn objective(predict_fn, loss_fn, params, inputs, targets) do
      preds = predict_fn.(params, inputs)
      loss = loss_fn.(preds, targets)
      {preds, loss}
    end

You can compute the gradient with respect to just the loss function by applying
a transform:

    {{preds, loss}, gradient} = value_and_grad(params, &objective(predict_fn, loss_fn, &1, inputs, targets), &elem(&1, 1))

`preds` can be re-used to compute other metrics such as accuracy, absolute error,
etc. without having to do another forward pass.

## defn/2

Defines a public numerical function.

## defnp/2

Defines a private numerical function.

Private numerical functions are always inlined by
their callers at compilation time. This happens to
all local function calls within `defn`.

## deftransform/1

Can be used to define bodiless clauses for multi-clause transforms.

See also: `deftransform/2`

## Examples

    deftransform foo(bar, baz \ 1)
    deftransform foo(bar, 1), do: bar
    deftransform foo(bar, baz), do: bar + baz

## deftransform/2

Defines a transform that executes the given `fun` with `arg`
when building `defn` expressions.

## Example

Take the following defn expression:

    defn tanh_power(a, b) do
      Nx.tanh(a) + Nx.pow(b, 2)
    end

Let's see a trivial example, which is to use `IO.inspect/1` to
print a tensor expression at definition time:

    defn tanh_power(a, b) do
      Nx.tanh(a) + Nx.pow(b, 2) |> my_inspect()
    end

    deftransformp my_inspect(expr), do: IO.inspect(expr)

Or:

    defn tanh_power(a, b) do
      res = Nx.tanh(a) + Nx.pow(b, 2)
      my_inspect(res)
      res
    end

When invoked in both cases, it will print the expression being built
by `defn`:

    #Nx.Defn.Expr<
      parameter a
      parameter c
      b = tanh [ a ] ()
      d = pow [ c, 2 ] ()
      e = add [ b, d ] ()
    >

Although, for convenience, you might use `print_expr/2` instead.

## deftransformp/1

Private function version for `deftransform/1`

## deftransformp/2

Private function version for `deftransform/2`