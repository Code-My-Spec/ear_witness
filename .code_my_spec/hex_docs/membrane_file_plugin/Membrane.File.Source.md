# Membrane.File.Source

Element that reads chunks of data from given file and sends them as buffers
through the output pad.
May also read from standard input by setting location to :stdin.

Can work in two modes, determined by the `seekable?` option.
Seekable mode is not supported when reading from standard input.