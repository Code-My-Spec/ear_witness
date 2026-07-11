# Membrane.Buffer

Structure representing a single chunk of data that flows between elements.

For now, it is just a wrapper around bitstring with optionally some metadata
attached to it, but in future releases we plan to support different payload
types.

## get_dts_or_pts/1

Returns `t:Membrane.Buffer.t/0` `:dts` if available or `:pts` if `:dts` is not set.
If none of them is set `nil` is returned.