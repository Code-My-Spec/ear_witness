# Anubis.Server.Registry.Local

ETS-based session registry for HTTP transports.

Uses a named ETS table with `read_concurrency: true` for fast lookups.
Monitors registered processes for automatic cleanup on crash/shutdown.