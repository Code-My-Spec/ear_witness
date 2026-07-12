# Anubis.Server.Authorization.IntrospectionValidator

Token validator using RFC 7662 Token Introspection.

Validates opaque bearer tokens by POSTing them to an authorization server's
introspection endpoint. Supports HTTP Basic authentication with client credentials.

## Configuration

    validator: {Anubis.Server.Authorization.IntrospectionValidator,
      introspection_endpoint: "https://auth.example.com/introspect",
      client_id: "my-client",
      client_secret: "my-secret"
    }

## Options

  * `:introspection_endpoint` — URL of the introspection endpoint (required)
  * `:client_id` — client ID for Basic authentication (optional)
  * `:client_secret` — client secret for Basic authentication (optional)