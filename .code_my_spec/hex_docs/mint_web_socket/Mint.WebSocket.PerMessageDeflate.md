# Mint.WebSocket.PerMessageDeflate

A WebSocket extension which compresses each message before sending it across
the wire

This extension is defined in
[rfc7692](https://www.rfc-editor.org/rfc/rfc7692.html).

## Options

* `:zlib_level` - (default: `:best_compression`) the compression level to
  use for the deflation zstream. See the `:zlib.deflateInit/6` documentation
  on the `Level` argument.
* `:zlib_memory_level` - (default: `8`) how much memory to allow for use
  during compression. See the `:zlib.deflateInit/6` documentation on the
  `MemLevel` argument.