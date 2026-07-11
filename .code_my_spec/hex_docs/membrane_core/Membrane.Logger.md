# Membrane.Logger

Wrapper around the Elixir logger. Adds Membrane prefixes and handles verbose logging.

## Prefixes

By default, this wrapper prepends each log with a prefix containing the context
of the log, such as element name. This can be turned off via configuration:

    use Mix.Config
    config :membrane_core, :logger, prefix: false

Regardless of the config, the prefix is passed to `Logger` metadata under `:mb_prefix` key.
Prefixes are passed via process dictionary, so they have process-wide scope,
but it can be extended with `get_prefix/0` and `set_prefix/1`.

## Verbose logging

For verbose debug logs that should be silenced by default, use `debug_verbose/2`
macro. Verbose logs are purged in the compile time, unless turned on via configuration:

    use Mix.Config
    config :membrane_core, :logger, verbose: true

Verbose debugs should be used for logs that are USUALLY USEFUL for debugging,
but printed so often that they make the output illegible. For example, it may
be a good idea to debug_verbose from within `c:Membrane.WithInputPads.handle_buffer/4`
or `c:Membrane.Element.WithOutputPads.handle_demand/5` callbacks.

## debug_verbose/2

Macro for verbose debug logs, that are silenced by default.

For details, see the ['verbose logging'](#module-verbose-logging) section of the moduledoc.

## log/3

Wrapper around `Logger.log/3` that adds Membrane prefix.

For details, see the ['prefixes'](#module-prefixes) section of the moduledoc.

## bare_log/3

Wrapper around `Logger.bare_log/3` that adds Membrane prefix.

For details, see the 'prefixes' section of the moduledoc.

## get_prefix/0

Returns the logger prefix.

Returns an empty string if no prefix is set.

## set_prefix/1

Sets the logger prefix. Avoid using in Membrane-managed processes.

This function is intended to enable setting prefix obtained in a Membrane-managed
process via `get_prefix/1`. If some custom data needs to be prepended to logs,
please use `Logger.metadata/1`.

Prefixes in Membrane-managed processes are set automatically and using this
function there would overwrite them, which is usually unintended.

## get_config/0

Returns the Membrane logger config.

## get_config/2

Returns value at given key in the Membrane logger config.