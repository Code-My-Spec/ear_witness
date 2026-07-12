# Peri.JSONSchema.Decoder

Decodes a JSON Schema (Draft 7) map into a Peri schema definition.

Returns `{:ok, schema}` on success or `{:error, errors}` if the resulting
Peri schema fails `Peri.validate_schema/1`.

Prefer `Peri.from_json_schema/1` as the public entry point.