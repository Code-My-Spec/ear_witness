# Peri.JSONSchema.Encoder

Encodes a Peri schema definition into a JSON Schema (Draft 7) map.

Field-level metadata attached via `{:meta, type, opts}` is read during
encoding and surfaced as JSON Schema annotation/format keywords. See
`@meta_keys` for the recognised vocabulary; unknown keys are dropped.

Dynamic Peri types (`:dependent`, `:cond`, `:custom`) cannot be expressed
statically. The `:on_unsupported` option controls the fallback:

  - `:omit` (default) — emit `%{}` (true schema)
  - `:true_schema` — same as `:omit`
  - `:raise` — raise `Peri.JSONSchema.Encoder.UnsupportedTypeError`

The `:exclude_meta_keys` option drops listed annotation keywords from the
output. Accepts any subset of the meta vocabulary plus `:default`. Useful
when emitting consumer-facing JSON Schema where `default` values are
validation-only and should not be exposed.

    Peri.to_json_schema(schema, exclude_meta_keys: [:default])

Prefer `Peri.to_json_schema/2` as the public entry point.