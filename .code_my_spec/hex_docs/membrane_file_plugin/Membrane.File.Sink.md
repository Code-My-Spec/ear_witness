# Membrane.File.Sink

Element that creates a file and stores incoming buffers there (in binary format).
Can also be used as a pipe to standard output by setting location to :stdout,
though this requires additional configuration.

When `Membrane.File.SeekSinkEvent` is received, the element starts writing buffers starting
from `position`. By default, it overwrites previously stored bytes. You can set `insert?`
field of the event to `true` to start inserting new buffers without overwriting previous ones.
Please note, that inserting requires rewriting the file, what negatively impacts performance.
For more information refer to `Membrane.File.SeekSinkEvent` moduledoc.

Pipeline logs are directed to standard output by default. To separate them from the sink's output
we recommend redirecting the logger to standard error. For simple use cases using the default logger
configuration (like stand-alone scripts) this can be achieved by simply calling redirect_logs_to_stderr/0.
See examples/file_to_pipe.exs for a working example.