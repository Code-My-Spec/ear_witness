# Kino.ETS

A kino for interactively viewing an ETS table.

## Examples

    tid = :ets.new(:users, [:set, :public])
    Kino.ETS.new(tid)

    Kino.ETS.new(:elixir_config)

## new/1

Creates a new kino displaying the given ETS table.

Note that private tables cannot be read by an arbitrary process,
so the given table must have either public or protected access.