# Anubis.Server.Context

Read-only session and request context, set by the SDK before each callback.

The Session process builds a fresh Context before every user callback invocation.
Mutations have no lasting effect — the Session always overwrites it.

For STDIO transport, `headers` is empty, `remote_ip` is nil, and `auth` is nil.
For HTTP transport, headers are normalized to lowercase string keys.

## Auth field

When OAuth 2.1 authorization is configured on the server, `auth` contains the
normalized claims map extracted from the validated bearer token:

    %{
      sub: "user-id",
      aud: "https://api.example.com",
      scope: "tools:read tools:write",
      scopes: ["tools:read", "tools:write"],
      exp: 1_234_567_890,
      iat: 1_234_567_800,
      client_id: "client-abc",
      raw_claims: %{}
    }

`auth` is `nil` when no authorization is configured or the transport is STDIO.