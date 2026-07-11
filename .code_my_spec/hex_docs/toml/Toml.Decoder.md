# Toml.Decoder



## decode!/2

Decodes a raw binary into a map.

`Toml.Error` is raised if decoding fails.

## decode/2

Decodes a raw binary safely, returns `{:ok, map}` or `{:error, reason}`

## decode_stream!/2

Decodes a stream.

Raises `Toml.Error` if decoding fails.

## decode_stream/2

Decodes a stream safely.

Returns same type as `decode/2`

## decode_file!/2

Decodes a file.

Raises `Toml.Error` if decoding fails.

## decode_file/2

Decodes a file safely.

Returns same type as `decode/2`