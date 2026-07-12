# Anubis.Server.Authorization.JWTValidator

JWT validator using JWKS (requires the `:jose` dependency).

Fetches the JWKS from the configured URI, caches the key set in
`:persistent_term` with a 5-minute TTL, then verifies the token
signature against the matching key.

Issuer validation is performed here when `:issuer` is configured.
`aud` and `exp` are validated by the authorization plug layer
(`Anubis.Server.Authorization.validate_audience/2` and
`validate_expiry/1`) after the validator returns claims.

## Configuration

    validator: {Anubis.Server.Authorization.JWTValidator,
      jwks_uri: "https://auth.example.com/.well-known/jwks.json",
      issuer: "https://auth.example.com"   # optional, enables iss validation
    }

## Options

  * `:jwks_uri` — URL of the JWKS endpoint (required)
  * `:issuer` — expected `iss` claim value (optional)

## JOSE Dependency

This module only exists when `:jose ~> 1.11` is present in the project deps.
Add it to your `mix.exs`:

    {:jose, "~> 1.11"}