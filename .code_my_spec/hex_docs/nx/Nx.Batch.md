# Nx.Batch

Creates a batch of tensors (and containers).

A batch is lazily traversed, concatenated, and padded upon `defn` invocation.

## new/0

Returns a new empty batch.

## key/2

Sets the batch key for the given batch.

## merge/2

Merges two batches.

The tensors on the left will appear before the tensors on the right.

The size and padding of both batches are summed. The padding still
applies only at the end of batch.

It will raise if the batch templates are incompatible.

## Examples

    iex> batch1 = Nx.Batch.stack([Nx.tensor(1), Nx.tensor(2), Nx.tensor(3)])
    iex> batch2 = Nx.Batch.concatenate([Nx.tensor([4, 5]), Nx.tensor([6, 7, 8])])
    iex> batch = Nx.Batch.merge(batch1, batch2)
    iex> batch.size
    8
    iex> Nx.Defn.jit_apply(&Function.identity/1, [batch])
    #Nx.Tensor<
      s32[8]
      [1, 2, 3, 4, 5, 6, 7, 8]
    >

## merge/1

Merges a list of batches.

See `merge/2`.

## split/2

Splits a batch in two, where the first one has at most `n` elements.

If there is any padding and the batch is not full, the amount of padding
necessary will be moved to the first batch and the remaining stays in the
second batch.

## Examples

    iex> batch = Nx.Batch.concatenate([Nx.tensor([1, 2]), Nx.tensor([3, 4, 5])])
    iex> {left, right} = Nx.Defn.jit_apply(&Function.identity/1, [Nx.Batch.split(batch, 3)])
    iex> left
    #Nx.Tensor<
      s32[3]
      [1, 2, 3]
    >
    iex> right
    #Nx.Tensor<
      s32[2]
      [4, 5]
    >

## pad/2

Configures the batch with the given padding.

The batch will be padded when consumed:

    iex> batch = Nx.Batch.stack([Nx.tensor(1), Nx.tensor(2), Nx.tensor(3)])
    iex> Nx.Defn.jit_apply(&Function.identity/1, [Nx.Batch.pad(batch, 2)])
    #Nx.Tensor<
      s32[5]
      [1, 2, 3, 0, 0]
    >

## concatenate/2

Concatenates the given entries to the batch.

Entries are concatenated based on their first axis.
If the first axis has multiple entries, each entry
is added to the size of the batch.

You can either concatenate to an existing batch
or skip the batch argument to create a new batch.

See `stack/2` if you want to stack entries instead
of concatenating them.

## Examples

If no batch is given, one is automatically created:

    iex> batch = Nx.Batch.concatenate([Nx.tensor([1]), Nx.tensor([2]), Nx.tensor([3])])
    iex> Nx.Defn.jit_apply(&Function.identity/1, [batch])
    #Nx.Tensor<
      s32[3]
      [1, 2, 3]
    >

But you can also concatenate to existing batches:

    iex> batch = Nx.Batch.concatenate([Nx.tensor([1]), Nx.tensor([2])])
    iex> batch = Nx.Batch.concatenate(batch, [Nx.tensor([3]), Nx.tensor([4])])
    iex> Nx.Defn.jit_apply(&Function.identity/1, [batch])
    #Nx.Tensor<
      s32[4]
      [1, 2, 3, 4]
    >

If the first axis has multiple entries, each entry counts
towards the size of the batch:

    iex> batch = Nx.Batch.concatenate([Nx.tensor([1, 2]), Nx.tensor([3, 4, 5])])
    iex> batch.size
    5
    iex> Nx.Defn.jit_apply(&Function.identity/1, [batch])
    #Nx.Tensor<
      s32[5]
      [1, 2, 3, 4, 5]
    >

What makes batches powerful is that they can concatenate
across containers:

    iex> container1 = {Nx.tensor([11]), Nx.tensor([21])}
    iex> container2 = {Nx.tensor([12]), Nx.tensor([22])}
    iex> batch = Nx.Batch.concatenate([container1, container2])
    iex> {batched1, batched2} = Nx.Defn.jit_apply(&Function.identity/1, [batch])
    iex> batched1
    #Nx.Tensor<
      s32[2]
      [11, 12]
    >
    iex> batched2
    #Nx.Tensor<
      s32[2]
      [21, 22]
    >

## stack/2

Stacks the given entries to the batch.

Each entry counts exactly as a single entry.
You can either stack to an existing batch
or skip the batch argument to create a new batch.

See `concatenate/2` if you want to concatenate entries
instead of stacking them.

## Examples

If no batch is given, one is automatically created:

    iex> batch = Nx.Batch.stack([Nx.tensor(1), Nx.tensor(2), Nx.tensor(3)])
    iex> batch.size
    3
    iex> Nx.Defn.jit_apply(&Function.identity/1, [batch])
    #Nx.Tensor<
      s32[3]
      [1, 2, 3]
    >

But you can also stack an existing batch:

    iex> batch = Nx.Batch.stack([Nx.tensor(1), Nx.tensor(2)])
    iex> batch = Nx.Batch.stack(batch, [Nx.tensor(3), Nx.tensor(4)])
    iex> batch.size
    4
    iex> Nx.Defn.jit_apply(&Function.identity/1, [batch])
    #Nx.Tensor<
      s32[4]
      [1, 2, 3, 4]
    >

What makes batches powerful is that they can concatenate
across containers:

    iex> container1 = {Nx.tensor(11), Nx.tensor(21)}
    iex> container2 = {Nx.tensor(12), Nx.tensor(22)}
    iex> batch = Nx.Batch.stack([container1, container2])
    iex> {batched1, batched2} = Nx.Defn.jit_apply(&Function.identity/1, [batch])
    iex> batched1
    #Nx.Tensor<
      s32[2]
      [11, 12]
    >
    iex> batched2
    #Nx.Tensor<
      s32[2]
      [21, 22]
    >