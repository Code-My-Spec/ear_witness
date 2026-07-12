# Anubis.Client.JSONSchemaConverter



## validator/1

Creates a validator function from a JSON Schema.

Returns a function that takes a value and returns either
`{:ok, value}` or `{:error, errors}`.