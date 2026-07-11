# Membrane.File.Sink.Multi

Element that writes buffers to a set of files. File is switched on event.

Files are named according to `naming_fun` passed in options.
This function receives sequential number of file and should return string.
It defaults to `path/to/file0.ext`, `path/to/file1.ext`, ...

The event type, which starts writing to a next file is passed by `split_event` option.
It defaults to `Membrane.File.SplitEvent`.