# Anubis.Server.Session.Store

Behaviour for session persistence adapters.

This module defines the interface for implementing session storage backends
that can persist MCP session state across server restarts. Implementations
can use various storage solutions like Redis, PostgreSQL, ETS, or any other
persistence mechanism.

## Implementing a Store

To implement a custom session store, create a module that implements all
the callbacks defined in this behaviour:

    defmodule MyApp.RedisStore do
      @behaviour Anubis.Server.Session.Store

      def start_link(opts) do
        # Initialize connection to storage backend
      end

      def save(session_id, state, opts) do
        # Persist session state
        :ok
      end

      def load(session_id, opts) do
        # Retrieve session state
        {:ok, state}
      end

      # ... implement other callbacks
    end

## Using a Store

Configure the session store in your application config:

    config :anubis_mcp, :session_store,
      adapter: MyApp.RedisStore,
      redis_url: "redis://localhost:6379",
      ttl: 1800

## Session Security

Stores should implement appropriate security measures:
- Generate secure session tokens for validation
- Encrypt sensitive data before storage
- Validate session ownership on reconnection
- Implement proper TTL for automatic cleanup