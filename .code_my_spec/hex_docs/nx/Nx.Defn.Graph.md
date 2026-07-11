# Nx.Defn.Graph

A module for splitting `Nx.Defn.Expr` into stages.

This module is used to split an `Nx.Defn.Expr` into stages,
which are then executed in a chain.

`split/2` and `t:Stage.t()` describe how to split
the graph and what's the expected result.

`run/2` executes the given graph against the provided arguments
in a sequential manner.

## split/2

Splits the received Nx.Defn.Expr into stages based on each tensor.

`expr_split_fn` is a function that receives an `Nx.Tensor` containing an `Nx.Defn.Expr`
and returns one of:

* `:before` - creates a stage that computes all arguments to the current node,
  then creates parameters for those arguments in subsequent stages
* `:after` - creates a stage that computes the current node and outputs it
* `:both` - applies both `:before` and `:after` in sequence, creating stages for dependencies and the target operation
* `:none` - no split occurs

## Examples

    iex> expr = Nx.Defn.debug_expr(fn x, y -> x |> Nx.negate() |> Nx.sin() |> Nx.cos() |> Nx.add(y) end).(1, 2)
    iex> [stage0, stage1] = Nx.Defn.Graph.split(expr, fn %Nx.Tensor{data: %Nx.Defn.Expr{op: op}} -> if op == :cos, do: :before, else: :none end)
    iex> {out0} = stage0.expr
    iex> out0
    #Nx.Tensor<
      f32
      
      Nx.Defn.Expr
      parameter a:0   s32
      b = negate a    s32
      c = sin b       f32
    >
    iex> stage1.expr
    #Nx.Tensor<
      f32
      
      Nx.Defn.Expr
      parameter a:1   f32
      parameter c:0   s32
      b = cos a       f32
      d = add b, c    f32
    >

## split/3

Splits the received Nx.Defn.Expr into stages based on each tensor and the accumulator.

`expr_split_fn` is a function that receives an `Nx.Tensor` and the accumulator,
returning `{decision, new_acc}` where `decision` is one of:

* `:before` - creates a stage that computes all arguments to the current node,
  then creates parameters for those arguments in subsequent stages
* `:after` - creates a stage that computes the current node and outputs it
* `:both` - applies both `:before` and `:after` in sequence, creating stages for dependencies and the target operation
* `:none` - no split occurs

The decision to split is made based on the expression and the accumulator.
This allows for more complex decisions to be made, such as splitting every 3 operations as in the example below.

    # Count operations and split every 3 operations
    split_fn = fn _tensor, count ->
      new_count = count + 1
      decision = if count > 0 and rem(new_count, 3) == 0, do: :before, else: :none
      {decision, new_count}
    end

    stages = Nx.Defn.Graph.split(expr, 0, split_fn)

## run/2

Executes the stage chain with the given arguments.