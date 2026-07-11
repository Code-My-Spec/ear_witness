# Nx.Defn.Kernel

All imported functionality available inside `defn` blocks.

This module can be used in `defn`.

## alias/2

Defines an alias, as in `Kernel.SpecialForms.alias/2`.

An alias allows you to refer to a module using its aliased
name. For example:

    defn some_fun(t) do
      alias Math.Helpers, as: MH
      MH.fft(t)
    end

If the `:as` option is not given, the alias defaults to
the last part of the given alias. For example,

    alias Math.Helpers

is equivalent to:

    alias Math.Helpers, as: Helpers

Finally, note that aliases define outside of a function also
apply to the function, as they have lexical scope:

    alias Math.Helpers, as: MH

    defn some_fun(t) do
      MH.fft(t)
    end

## import/2

Imports functions and macros into the current scope,
as in `Kernel.SpecialForms.import/2`.

Imports are typically discouraged in favor of `alias/2`.

## Examples

    defn some_fun(t) do
      import Math.Helpers
      fft(t)
    end

## require/2

Requires a module in order to use its macros, as in `Kernel.SpecialForms.require/2`.

## Examples

    defn some_fun(t) do
      require NumericalMacros

      NumericalMacros.some_macro t do
        ...
      end
    end

## cond/1

Evaluates the expression corresponding to the first
clause that evaluates to a truthy value.

It has the format of:

    cond do
      condition1 ->
        expr1

      condition2 ->
        expr2

      true ->
        expr3
    end

The conditions must be a scalar. Zero is considered false,
any other number is considered true. The booleans `false` and
`true` are supported, but any other value will raise.

All clauses are normalized to the same type and are broadcast
to the same shape. The last condition must always evaluate to
true. All clauses are executed in the device, unless they can
be determined to always be true/false while building the numerical
expression.

## Examples

    cond do
      Nx.all(Nx.greater(a, 0)) -> b * c
      Nx.all(Nx.less(a, 0)) -> b + c
      true -> b - c
    end

When a `defn` is invoked, all `cond` clauses are traversed
and expanded in order to build their expressions. This means that,
**if you attempt to raise in any clause, then it will always raise**.
You can only `raise` in limited situations inside `defn`, see
`raise/2` for more information.

## case/2

Pattern matches the result of `expr` against the given clauses.

For example:

    case Nx.shape(tensor) do
      {_} -> implementation_for_rank_one(tensor)
      {_, _} -> implementation_for_rank_two(tensor)
      _ -> implementation_for_rank_n(tensor)
    end

Opposite to `cond/2` and `if/2`, which can execute the branching
in the device, `case`s are always expanded when building the
expression, and never on the device. This allows `case/2` to work
very similarly to Elixir's own `Kernel.SpecialForms.case/2`,
with only the following restrictions in place:

  * `case` inside defn only accepts structs, atoms, integers, and tuples as arguments
  * `case` can match on struct names but not on its fields
  * guards in `case` inside defn can only access variables defined within the pattern

Here is an example of `case` with guards:

    case Nx.shape(tensor) do
      {x, y} when x > y -> implementation_for_tall(tensor)
      {x, y} when x < y -> implementation_for_wide(tensor)
      {x, x} -> implementation_for_square(tensor)
    end

## print_expr/2

Prints the given expression to the terminal.

It returns the given expressions.

## Examples

    defn tanh_grad(t) do
      grad(t, &Nx.tanh/1) |> print_expr()
    end

When invoked, it will print the expression being built by `defn`:

    #Nx.Tensor<
      Nx.Defn.Expr
      parameter a s32
      parameter c s32
      b = tanh [ a ] f64
      d = pow [ c, 2 ] s32
      e = add [ b, d ] f64
    >

## print_value/2

Shortcut for `print_value/3`.

## print_value/3

Prints the value at runtime to the terminal.

The given expression is transformed with `fun` before printing.

This function is implemented on top of `hook/3` and therefore
has the following restrictions:

  * It can only inspect tensors and `Nx.Container`
  * The return value of this function must be part of the output

All options are passed to `IO.inspect/2`.

## Examples

    defn tanh_grad(t) do
      grad(t, fn t ->
        t
        |> Nx.tanh()
        |> print_value()
      end)
    end

    defn tanh_grad(t) do
      grad(t, fn t ->
        t
        |> Nx.tanh()
        |> print_value(label: "tanh")
      end)
    end

    defn tanh_grad(t) do
      grad(t, fn t ->
        t
        |> Nx.tanh()
        |> print_value(fn t -> Nx.sum(t) end)
      end)
    end

## stop_grad/1

Stops computing the gradient for the given expression.

It effectively annotates the gradient for the given
expression is 1.0.

## Examples

    expr = stop_grad(expr)

## custom_grad/3

Defines a custom gradient for the given expression.

It also expects a list of inputs of the gradient and a `fun`
to compute the gradient. The function will be called with the
current gradient. It must return a list of arguments and their
updated gradient to continue applying `grad` on.

## Examples

For example, if the gradient of `cos(t)` were to be
implemented by hand:

    def cos(t) do
      custom_grad(Nx.cos(t), [t], fn g ->
        [-g * Nx.sin(t)]
      end)
    end

## +/1

Element-wise unary plus operator.

Simply returns the given argument.

## Examples

    defn plus_and_minus(a) do
      {+a, -a}
    end

## -/1

Element-wise unary plus operator.

It delegates to `Nx.negate/1`.

## Examples

    defn plus_and_minus(a) do
      {+a, -a}
    end

## ../0

Creates the full-slice range `0..-1//1`.

This function returns a range with the following properties:

  * When enumerated, it is empty

  * When used as a `slice`, it returns the sliced element as is

## Examples

    iex> t = Nx.tensor([1, 2, 3])
    iex> t[..]
    #Nx.Tensor<
      s32[3]
      [1, 2, 3]
    >

## ../2

Builds a range.

Ranges are inclusive and both sides must be integers.

The step of the range is computed based on the first
and last values of the range.

## Examples

    iex> t = Nx.tensor([1, 2, 3])
    iex> t[1..2]
    #Nx.Tensor<
      s32[2]
      [2, 3]
    >

## ..///3

Builds a range with step.

Ranges are inclusive and both sides must be integers.

## Examples

    iex> t = Nx.tensor([1, 2, 3])
    iex> t[1..2//1]
    #Nx.Tensor<
      s32[2]
      [2, 3]
    >

## +/2

Element-wise addition operator.

It delegates to `Nx.add/2` (supports broadcasting).

## Examples

    defn add(a, b) do
      a + b
    end

## -/2

Element-wise subtraction operator.

It delegates to `Nx.subtract/2` (supports broadcasting).

## Examples

    defn subtract(a, b) do
      a - b
    end

## */2

Element-wise multiplication operator.

It delegates to `Nx.multiply/2` (supports broadcasting).

## Examples

    defn multiply(a, b) do
      a * b
    end

## **/2

Element-wise power operator.

It delegates to `Nx.pow/2` (supports broadcasting).

## Examples

    defn pow(a, b) do
      a ** b
    end

## //2

Element-wise division operator.

It delegates to `Nx.divide/2` (supports broadcasting).

## Examples

    defn divide(a, b) do
      a / b
    end

## div/2

Element-wise quotient operator.

It delegates to `Nx.quotient/2` (supports broadcasting).

## Examples

    defn quotient(a, b) do
      div(a, b)
    end

## rem/2

Element-wise remainder operation.

It delegates to `Nx.remainder/2` (supports broadcasting).

## Examples

    defn divides_by_5?(a) do
      rem(a, 5)
      |> Nx.any()
      |> Nx.equal(Nx.tensor(1))
    end

## max/2

Element-wise maximum operation.

It delegates to `Nx.max/2` (supports broadcasting).

## Examples

    defn min_max(a, b) do
      {min(a, b), max(a, b)}
    end

## min/2

Element-wise minimum operation.

It delegates to `Nx.min/2` (supports broadcasting).

## Examples

    defn min_max(a, b) do
      {min(a, b), max(a, b)}
    end

## __and__/2

Element-wise logical AND operation.

Zero is considered false, all other numbers
are considered true.

It delegates to `Nx.logical_and/2` (supports broadcasting).

It does not support short-circuiting.

## Examples

    defn and_or(a, b) do
      {a and b, a or b}
    end

## __or__/2

Element-wise logical OR operation.

Zero is considered false, all other numbers
are considered true.

It delegates to `Nx.logical_or/2` (supports broadcasting).

It does not support short-circuiting.

## Examples

    defn and_or(a, b) do
      {a and b, a or b}
    end

## __not__/1

Element-wise logical NOT operation.

Zero is considered false, all other numbers
are considered true.

It delegates to `Nx.logical_not/1`.

## Examples

    defn logical_not(a), do: not a

## &&&/2

Element-wise bitwise AND operation.

Only integer tensors are supported.
It delegates to `Nx.bitwise_and/2` (supports broadcasting).

## Examples

    defn and_or(a, b) do
      {a &&& b, a ||| b}
    end

## |||/2

Element-wise bitwise OR operation.

Only integer tensors are supported.
It delegates to `Nx.bitwise_or/2` (supports broadcasting).

## Examples

    defn and_or(a, b) do
      {a &&& b, a ||| b}
    end

## <<</2

Element-wise left shift operation.

Only integer tensors are supported.
It delegates to `Nx.left_shift/2` (supports broadcasting).

## Examples

    defn shift_left_and_right(a, b) do
      {a <<< b, a >>> b}
    end

## >>>/2

Element-wise right shift operation.

Only integer tensors are supported.
It delegates to `Nx.right_shift/2` (supports broadcasting).

## Examples

    defn shift_left_and_right(a, b) do
      {a <<< b, a >>> b}
    end

## __equal__/2

Element-wise equality operation.

It delegates to `Nx.equal/2`.

## Examples

    defn check_equality(a, b) do
      a == b
    end

## __not_equal__/2

Element-wise inequality operation.

It delegates to `Nx.not_equal/2`.

## Examples

    defn check_inequality(a, b) do
      a != b
    end

## __less_than__/2

Element-wise less than operation.

It delegates to `Nx.less/2`.

## Examples

    defn check_less_than(a, b) do
      a < b
    end

## __more_than__/2

Element-wise greater than operation.

It delegates to `Nx.greater/2`.

## Examples

    defn check_greater_than(a, b) do
      a > b
    end

## __less_than_equal_to__/2

Element-wise less-equal operation.

It delegates to `Nx.less_equal/2`.

## Examples

    defn check_less_equal(a, b) do
      a <= b
    end

## __more_than_equal_to__/2

Element-wise greater-equal operation.

It delegates to `Nx.greater_equal/2`.

## Examples

    defn check_greater_equal(a, b) do
      a >= b
    end

## keyword!/2

Ensures the first argument is a `keyword` with the given
keys and default values.

The second argument must be a list of atoms, specifying
a given key, or tuples specifying a key and a default value.
If any of the keys in the `keyword` is not defined in
`values`, it raises an error.

This does not validate required keys. For such, use `assert_keys/2`
instead.

This is equivalent to Elixir's `Keyword.validate!/2`.

## Examples

    iex> keyword!([], [one: 1, two: 2]) |> Enum.sort()
    [one: 1, two: 2]

    iex> keyword!([two: 3], [one: 1, two: 2]) |> Enum.sort()
    [one: 1, two: 3]

If atoms are given, they are supported as keys but do not
provide a default value:

    iex> keyword!([], [:one, two: 2]) |> Enum.sort()
    [two: 2]

    iex> keyword!([one: 1], [:one, two: 2]) |> Enum.sort()
    [one: 1, two: 2]

Passing an unknown key raises:

    iex> keyword!([three: 3], [one: 1, two: 2])
    ** (ArgumentError) unknown key :three in [three: 3], expected one of [:one, :two]

## |>/2

Pipes the argument on the left to the function call on the right.

It delegates to `Kernel.|>/2`.

## Examples

    defn exp_sum(t) do
      t
      |> Nx.exp()
      |> Nx.sum()
    end

## if/2

Provides if/else expressions.

The first argument must be a scalar. Zero is considered false,
any other number is considered true. The booleans `false` and
`true` are supported, but any other value will raise.

The second argument is a keyword list with `do` and `else`
blocks. The sides are broadcast to return the same shape
and normalized to return the same type.

## Examples

    if Nx.any(Nx.equal(t, 0)) do
      0.0
    else
      1 / t
    end

In case else is not given, it is assumed to be 0 with the
same as the do clause. If you want to nest multiple conditionals,
see `cond/1` instead.

When a `defn` is invoked, both `do`/`else` clauses are traversed
and expanded in order to build their expressions. This means that,
**if you attempt to raise in any clause, then it will always raise**.
You can only `raise` in limited situations inside `defn`, see
`raise/2` for more information.

## while/4

Defines a `while` loop.

It expects the `initial` arguments, a `condition` expression, and
a `block`:

    while initial, condition do
      block
    end

`condition` must return a scalar tensor where 0 is false and any
other number is true. The given `block` will be executed while
`condition` is true. Each invocation of `block` must return a
value in the same shape as `initial` arguments.

`while` will return the value of the last execution of `block`.
If `block` is never executed because the initial `condition` is
false, it returns `initial`.

> Note: you must prefer to use the operations in the `Nx` module,
> whenever available, instead of writing your own loops.

## Examples

A simple loop that increments `x` until it is `10` can be written as:

    while x = 0, Nx.less(x, 10) do
      x + 1
    end

However, it is important to note that all variables you intend
to use inside the "while" must be explicitly given as argument
to "while". For example, imagine the amount we want to increment
by in the example above is given by a variable `y`. The following
example is invalid:

    while x = 0, Nx.less(x, 10) do
      x + y
    end

Instead, both `x` and `y` must be passed as variables to `while`:

    while {x = 0, y}, Nx.less(x, 10) do
      {x + y, y}
    end

Similarly, to compute the factorial of `x` using `while`:

    defn factorial(x) do
      {factorial, _} =
        while {factorial = 1, x}, Nx.greater(x, 1) do
          {factorial * x, x - 1}
        end

      factorial
    end

## Generators

Inspired by Elixir's [for-comprehensions](`Kernel.SpecialForms.for/1`),
`while` in `defn` supports generators. Generators may be tensors or ranges.

### Tensor generators

When the generator is a tensor, Nx will traverse its highest dimension.
For example, you could sum a one dimensional tensor as follows:

    while acc = 0, i <- tensor do
      acc + i
    end

> Note: implementing `sum` using `while`, as above, is done as an example.
> In practice, you must prefer to use the operations in the `Nx` module,
> whenever available, instead of writing your own loops.

One advantage of using generators is that you can also unroll the loop
for performance:

    while acc = 0, i <- tensor, unroll: true do
      acc + i
    end

Or unroll it in batches:

    while acc = 0, i <- tensor, unroll: 4 do
      acc + i
    end

Unrolling means that the the `while` body is automatically duplicated
a certain amount of times, as if you wrote all iterations by hand. This
makes the final expression larger, which causes a longer compilation
time, however it enables additional compile-time optimizations (such as
fusion), improving the runtime efficiency.

In case the tensor for generator is vectorized, `:unroll` will only
affect the non-vectorized part. For instance, if a tensor has shape `{4}`
and vectorized axes `[x: 2][y: 3]`, `unroll: true` will only unroll
the `4` inner iterations.

### Range generators

A range can also be given as a generator. The range may be increasing or
decreasing. Also remember that ranges in Elixir are inclusive on both
begin and end. The sum example from the previous section could also be
written with ranges:

    while {tensor, acc = 0}, i <- 0..Nx.axis_size(tensor, 0)-1 do
      acc + tensor[i]
    end

## tap/2

Pipes `value` to the given `fun` and returns the `value` itself.

Useful for running synchronous side effects in a pipeline.

## Examples

Let's suppose you want to inspect an expression in the middle of
a pipeline. You could write:

    a
    |> Nx.add(b)
    |> tap(&print_expr/1)
    |> Nx.multiply(c)

## then/2

Pipes `value` into the given `fun`.

In other words, it invokes `fun` with `value` as argument.
This is most commonly used in pipelines, allowing you
to pipe a value to a function outside of its first argument.

## Examples

    a
    |> Nx.add(b)
    |> then(&Nx.subtract(c, &1))

## elem/2

Gets the element at the zero-based index in tuple.

It raises ArgumentError when index is negative or it
is out of range of the tuple elements.

## Examples

    iex> tuple = {1, 2, 3}
    iex> elem(tuple, 0)
    1

## @/1

Reads a module attribute at compilation time.

It is useful to inject code constants into `defn`.
It delegates to `Kernel.@/1`.

## Examples

    @two_per_two Nx.tensor([[1, 2], [3, 4]])
    defn add_2x2_attribute(t), do: t + @two_per_two

## hook/2

Shortcut for `hook/3`.

## hook/3

Defines a hook.

Hooks are a mechanism to execute an anonymous function for
side-effects with runtime tensor values.

Let's see an example:

    defmodule Hooks do
      import Nx.Defn

      defn add_and_mult(a, b) do
        add = hook(a + b, fn tensor -> IO.inspect({:add, tensor}) end)
        mult = hook(a * b, fn tensor -> IO.inspect({:mult, tensor}) end)
        {add, mult}
      end
    end

Note a hook can only access the variables passed as arguments
to the hook. It cannot access any other variable defined in
`defn` outside of the hook.

The `defn` above defines two hooks, one is called with the
value of `a + b` and another with `a * b`. Once you invoke
the function above, you should see this printed:

    Hooks.add_and_mult(2, 3)
    {:add, #Nx.Tensor<
       s32
       5
    >}
    {:mult, #Nx.Tensor<
       s32
       6
    >}

In other words, the `hook` function accepts a tensor
expression as argument and it will invoke a custom
function with a tensor value at runtime. `hook` returns
the result of the given expression. The expression can
be any tensor or a `Nx.Container`.

Note **you must return the result of the `hook` call**.
For example, the code below won't inspect the `:add`
tuple, because the hook is not returned from `defn`:

    defn add_and_mult(a, b) do
      _add = hook(a + b, fn tensor -> IO.inspect({:add, tensor}) end)
      mult = hook(a * b, fn tensor -> IO.inspect({:mult, tensor}) end)
      mult
    end

We will learn how to hook into a value that is not part
of the result in the "Hooks and tokens" section.

## Named hooks

It is possible to give names to the hooks. This allows them
to be defined or overridden by calling `Nx.Defn.jit/2`.
Let's see an example:

    defmodule Hooks do
      import Nx.Defn

      defn add_and_mult(a, b) do
        add = hook(a + b, :hooks_add)
        mult = hook(a * b, :hooks_mult)
        {add, mult}
      end
    end

Now you can pass the hook as argument as follows:

    hooks = %{
      hooks_add: fn tensor ->
        IO.inspect {:add, tensor}
      end
    }

    fun = Nx.Defn.jit(&Hooks.add_and_mult/2, hooks: hooks)
    fun.(Nx.tensor(2), Nx.tensor(3))

> **Important!** We recommend to prefix your hook names
> by the name of your project to avoid conflicts.

If a named hook is not given, compilers can optimize
that away and not transfer the tensor from the device
in the first place.

You can also mix named hooks with callbacks:

    defn add_and_mult(a, b) do
      add = hook(a + b, :hooks_add, fn tensor -> IO.inspect({:add, tensor}) end)
      mult = hook(a * b, :hooks_mult, fn tensor -> IO.inspect({:mult, tensor}) end)
      {add, mult}
    end

If a hook with the same name is given to `Nx.Defn.jit/2`,
then it will override the default callback.

## Hooks and tokens

So far, we have always returned the result of the `hook`
call. However, what happens if the values we want to
hook are not part of the return value, such as below?

    defn add_and_mult(a, b) do
      _add = hook(a + b, :hooks_add, &IO.inspect({:add, &1}))
      mult = hook(a * b, :hooks_mult, &IO.inspect({:mult, &1}))
      mult
    end

In such cases, you must use tokens. Tokens are used to
create an ordering over hooks, ensuring hooks execute
in a certain sequence:

    defn add_and_mult(a, b) do
      token = create_token()
      {token, _add} = hook_token(token, a + b, :hooks_add, &IO.inspect({:add, &1}))
      {token, mult} = hook_token(token, a * b, :hooks_mult, &IO.inspect({:mult, &1}))
      attach_token(token, mult)
    end

The example above creates a token and uses `hook_token/4`
to create hooks attached to their respective tokens. By using a token,
we guarantee that those hooks will be invoked in the order
in which they were defined. Then, at the end of the function,
we attach the token (and its associated hooks) to the result `mult`.

In fact, the `hook/3` function is implemented roughly like this:

    def hook(tensor_expr, name, function) do
      {token, result} = hook_token(create_token(), tensor_expr, name, function)
      attach_token(token, result)
    end

Note you must attach the token at the end, otherwise the hooks
will be "lost", as if they were not defined. This also applies
to conditionals and loops. The token must be attached within
the branch they are used. For example, this won't work:

    token = create_token()

    {token, result} =
      if Nx.any(value) do
        hook_token(token, some_value)
      else
        hook_token(token, another_value)
      end

    attach_token(token, result)

Instead, you must write:

    token = create_token()

    if Nx.any(value) do
      {token, result} = hook_token(token, some_value)
      attach_token(token, result)
    else
      {token, result} = hook_token(token, another_value)
      attach_token(token, result)
    end

## hook_token/3

Shortcut for `hook_token/4`.

## hook_token/4

Defines a hook with an existing token. See `hook/3`.

## create_token/0

Creates a token for hooks. See `hook/3`.

## attach_token/2

Attaches a token to an expression. See `hook/3`.

## assert_keys/2

Asserts the keyword list has the given keys.

If it succeeds, it returns the given keyword list. Raises
an error otherwise.

## Examples

To assert the tensor is a scalar, you can pass the empty tuple `shape`:

    iex> assert_keys([one: 1, two: 2], [:one, :two])
    [one: 1, two: 2]

If the keys are not available, an error is raised:

    iex> assert_keys([one: 1, two: 2], [:three])
    ** (ArgumentError) expected key :three in keyword list, got: [one: 1, two: 2]

## raise/1

Raises a runtime exception with the given `message`.

See `raise/2` for more information on exceptions inside `defn`.

## <>/2

Concatenates two strings.

Equivalent to `Kernel.<>/2`.