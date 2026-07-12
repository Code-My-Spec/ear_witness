# Anubis.MCP.ElicitationSchema

Validator for the restricted JSON Schema subset allowed in elicitation requests.

Per the MCP 2025-06-18 specification, an `elicitation/create` `requestedSchema`
must be a flat object whose properties are all primitives. This module validates
both the schema map itself (`validate/1`) and content payloads against a
previously validated schema (`validate_content/2`).

Permitted property schemas:

  * `string` with optional `minLength`, `maxLength`, `format`
    (one of `"email"`, `"uri"`, `"date"`, `"date-time"`)
  * `string` enum with `enum` and optional matching `enumNames`
  * `number` / `integer` with optional `minimum`, `maximum`
  * `boolean` with optional `default`

## validate/1

Validates a `requestedSchema` map fits the elicitation subset.

Returns `:ok` or `{:error, reason}` where `reason` is a human-readable string.

## validate_content/2

Validates a content map against an already-validated elicitation schema.

Returns `:ok` or `{:error, reason}`.