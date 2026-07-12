# Peri.Walker

Depth-first schema rewriter.

`Peri.walk/2` (delegated here) traverses a schema in pre-order, invoking the
supplied callback on every subtree. Callback contract depends on context:

  * **Map / keyword schema entries** — invoked as `{:field, key, value}`.
    Return one of:

      * `{:cont, {:field, new_key, new_value}}` — replace the entry; the
        walker recurses into `new_value` as a type expression. `new_key` may
        differ from the original (rename) and may be any term valid as a key
        for the surrounding container.
      * `:drop` — remove the entry from the parent map / keyword list.

  * **Every other subtree** — invoked as the type expression itself
    (e.g. `:string`, `{:list, …}`, `{:multi, …}`, a nested map). Return:

      * `{:cont, new_node}` — replace and continue walking children of
        `new_node`.
      * `:drop` — not allowed in this context; raises.

Map keys are not visited as standalone nodes; constraint option lists
(e.g. `[gte: 18, error: "…"]`), `:enum` members, `:literal` values, `:ref`
names, `:multi` tags, callbacks, and transforms are not visited either —
only sub-schemas and field entries are.

Example — make every required field optional:

    Peri.walk(schema, fn
      {:required, t} -> {:cont, t}
      {:required, t, _opts} -> {:cont, t}
      other -> {:cont, other}
    end)

Example — strip private fields from a map schema:

    Peri.walk(schema, fn
      {:field, k, _v} when k in [:internal_id, :secret] -> :drop
      other -> {:cont, other}
    end)

Example — rename `email` to `:login`:

    Peri.walk(schema, fn
      {:field, :email, v} -> {:cont, {:field, :login, v}}
      other -> {:cont, other}
    end)