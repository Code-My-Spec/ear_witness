# Anubis.Server.Authorization.Validator

Behaviour for token validators.

Implement this behaviour to plug in a custom token validation strategy.
Two built-in implementations are provided:

  * `Anubis.Server.Authorization.JWTValidator` — validates JWTs using JWKS (requires `:jose`)
  * `Anubis.Server.Authorization.IntrospectionValidator` — validates opaque tokens via RFC 7662

## Example

    defmodule MyApp.CustomValidator do
      @behaviour Anubis.Server.Authorization.Validator

      @impl true
      def validate_token(token, _config) do
        case MyApp.TokenStore.lookup(token) do
          {:ok, claims} -> {:ok, claims}
          :error -> {:error, :token_not_found}
        end
      end
    end