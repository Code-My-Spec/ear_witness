# Nx.Defn.Token

A `defn` token used by hooks.

## Documentation for compilers

The token has a `hooks` field as a list of maps of the shape:

    %{
      expr: Nx.Tensor.t | Nx.Container.t,
      name: atom(),
      callback: (Nx.Tensor.t | Nx.Container.t -> term()) | nil
    }

The `hooks` field must only be accessed by `defn` compilers.