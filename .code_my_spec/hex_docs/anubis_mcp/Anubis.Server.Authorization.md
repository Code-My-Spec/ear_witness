# Anubis.Server.Authorization

OAuth 2.1 resource server authorization support.

Provides configuration, metadata building, and token validation primitives
for securing MCP servers with bearer token authorization.

## Standards Implemented

  * RFC 6750 — Bearer Token Usage
  * RFC 9728 — Protected Resource Metadata
  * RFC 8707 — Resource Indicators (audience validation)
  * RFC 7662 — Token Introspection
  * RFC 7519 — JSON Web Token (JWT)

## Configuration

    use MyServer,
      authorization: [
        authorization_servers: ["https://auth.example.com"],
        resource: "https://api.example.com",
        realm: "mcp",
        scopes_supported: ["tools:read", "tools:write"],
        validator: {Anubis.Server.Authorization.JWTValidator,
          jwks_uri: "https://auth.example.com/.well-known/jwks.json"}
      ]

## Claims map

After successful validation, a normalized claims map is stored in `Context.auth`:

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

## parse_config!/1

Parses and validates the authorization configuration keyword list.

Raises `ArgumentError` if required fields are missing or invalid.

## Examples

    config = Authorization.parse_config!(
      authorization_servers: ["https://auth.example.com"],
      resource: "https://api.example.com",
      validator: {MyValidator, []}
    )

## build_resource_metadata/1

Builds the RFC 9728 protected resource metadata map.

## Examples

    Authorization.build_resource_metadata(config)
    # => %{
    #      "resource" => "https://api.example.com",
    #      "authorization_servers" => ["https://auth.example.com"],
    #      "scopes_supported" => ["tools:read"],
    #      "bearer_methods_supported" => ["header"]
    #    }

## build_www_authenticate/2

Builds the `WWW-Authenticate` header value for a 401 unauthorized response.

Includes `resource_metadata` URL per RFC 9728.

## Examples

    Authorization.build_www_authenticate(config, :unauthorized)
    # => ~s(Bearer realm="mcp", resource_metadata="https://api.example.com/.well-known/oauth-protected-resource")

## validate_audience/2

Validates that the token `aud` claim matches the server's canonical resource URI.

Returns `:ok` when the audience matches, `{:error, :invalid_audience}` otherwise.

## Examples

    Authorization.validate_audience(%{aud: "https://api.example.com"}, config)
    # => :ok

    Authorization.validate_audience(%{aud: "https://other.example.com"}, config)
    # => {:error, :invalid_audience}

## validate_expiry/1

Validates that the token has not expired.

Compares `exp` against the current Unix timestamp.
Returns `:ok` if not expired, `{:error, :token_expired}` otherwise.
Tokens without `exp` are treated as non-expiring.

## Examples

    Authorization.validate_expiry(%{exp: future_timestamp})
    # => :ok

## validate_scopes/2

Validates that the claims contain all required scopes.

Returns `:ok` when all `required` scopes are present in the claims,
`{:error, {:insufficient_scope, required_scopes}}` otherwise.

## Examples

    Authorization.validate_scopes(%{scopes: ["tools:read", "tools:write"]}, ["tools:read"])
    # => :ok

    Authorization.validate_scopes(%{scopes: ["tools:read"]}, ["tools:write"])
    # => {:error, {:insufficient_scope, ["tools:write"]}}

## well_known_url/1

Returns the canonical `/.well-known/oauth-protected-resource` URL for a resource URI.

## Examples

    Authorization.well_known_url("https://api.example.com")
    # => "https://api.example.com/.well-known/oauth-protected-resource"

## normalize_claims/1

Normalizes raw claims (string-keyed map) into the canonical claims shape.

Parses the `scope` string into a `scopes` list for convenient membership checks.
If the raw claims already contain a `scopes` list (string- or atom-keyed), it is
preserved as-is so custom validators that emit pre-normalized data are honored.