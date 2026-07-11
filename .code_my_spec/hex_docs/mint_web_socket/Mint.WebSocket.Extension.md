# Mint.WebSocket.Extension

Tools for defining extensions to the WebSocket protocol

The WebSocket protocol allows for extensions which act as middle-ware
in the encoding and decoding of frames. In `Mint.WebSocket`, extensions are
written as module which implement the `Mint.WebSocket.Extension` behaviour.

The common "permessage-deflate" extension is built-in to `Mint.WebSocket` as
`Mint.WebSocket.PerMessageDeflate`. This extension should be used as a
reference when writing future extensions, but future extensions should be
written as separate libraries which extend `Mint.WebSocket` instead of
built-in. Also note that extensions must operate on the internal
representations of frames using the records defined in an internal module.

## encode/2

Invoked when decoding frames after receiving them from the wire

Error tuples bubble up to `Mint.WebSocket.decode/2`.