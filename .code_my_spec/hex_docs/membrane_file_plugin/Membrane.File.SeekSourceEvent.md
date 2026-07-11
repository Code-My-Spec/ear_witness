# Membrane.File.SeekSourceEvent

Event that triggers seeking and reading in `Membrane.File.Source` working in
`seekable?: true` mode.

When `inspect(__MODULE__)` is received by the source, the source starts reading
data from the given position in file, specified by the `:start` field of the event's
struct. The source reads up to `size_to_read` bytes of the data from file (it can
read less if the file ends).
If the event is set with `last?: true`, once `size_to_read` bytes are read or the
file ends, the source will return `end_of_stream` action on the `:output` pad.