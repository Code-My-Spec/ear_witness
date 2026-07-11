# Unifex.CodeGenerator.Utils

Utilities for code generation.

## sigil_g/2

Sigil used for templating generated code.

## sanitize_var_name/1

Replaces special characters such as: `.`, `->` and array brackets e.g. `var_name[i]`
with underscores.

In case of arrays `var_name[i]` results in `var_name_i`.

## generate_serialization/2

Traverses Elixir specification AST and creates C data types serialization
with `serializers`.