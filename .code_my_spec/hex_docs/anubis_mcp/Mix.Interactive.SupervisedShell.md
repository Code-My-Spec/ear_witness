# Mix.Interactive.SupervisedShell



## start/1

Starts a supervised interactive shell session.

## Options
  * `:transport_module` - The transport module (e.g., Anubis.Transport.StreamableHTTP)
  * `:transport_opts` - Options for starting the transport
  * `:client_opts` - Options for starting the client (excluding transport)
  * `:max_restarts` - Maximum number of automatic restarts (default: 3)