# Anubis.Server.Session.Store.Redis

Redis-based session store implementation.

Uses Redix for Redis communication and provides persistent session storage
with automatic expiration and connection pooling.

## Configuration

    config :anubis_mcp, :session_store,
      adapter: Anubis.Server.Session.Store.Redis,
      redis_url: "redis://localhost:6379/0",
      pool_size: 10,
      ttl: 1_800_000, # 30 minutes in milliseconds
      namespace: "anubis:sessions",
      connection_name: :anubis_redis,
      redix_opts: []  # Optional Redix connection options

## SSL/TLS Configuration

For Redis servers requiring TLS (like Upstash), pass SSL options via `:redix_opts`:

    config :anubis_mcp, :session_store,
      adapter: Anubis.Server.Session.Store.Redis,
      redis_url: "rediss://default:password@host.upstash.io:6379",
      redix_opts: [
        ssl: true,
        socket_opts: [
          customize_hostname_check: [
            match_fun: :public_key.pkix_verify_hostname_match_fun(:https)
          ]
        ]
      ]

## Features

- Automatic session expiration using Redis TTL
- Last-write-wins semantics for session updates
- Connection pooling for high concurrency
- Namespace support for multi-tenant deployments