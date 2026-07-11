# Bundlex.Helper.PathHelper



## fix_slashes/1

Fixes slashes in the given path to match convention used on current
operating system.

Internally all elixir functions use slash as a path separator, even if
running on windows, and it's not a bug but a feature (lol).

See https://github.com/elixir-lang/elixir/issues/1236