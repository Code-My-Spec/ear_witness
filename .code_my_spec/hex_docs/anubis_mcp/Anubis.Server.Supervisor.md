# Anubis.Server.Supervisor



## start_link/2

Starts the server supervisor.

## Parameters

  * `server` - The module implementing `Anubis.Server`
  * `opts` - Options including:
    * `:transport` - Transport configuration (required)
    * `:name` - Supervisor name (optional, defaults to atom name)
    * `:registry` - `{module, opts}` for custom registry (auto-selected by default)
    * `:supervisor` - `{module, opts}` for custom session supervisor (defaults to `{DynamicSupervisor, []}`)
    * `:session_idle_timeout` - Time in milliseconds before idle sessions expire (default: 30 minutes)
    * `:request_timeout` - Time limit in milliseconds for server requests (defaults to 30s)

## start_session/2

Starts a new session under the configured session supervisor.

## stop_session/3

Terminates a session.

## get_authorization_config/1

Returns the parsed authorization config for the given server module, or `nil`
if no authorization is configured.