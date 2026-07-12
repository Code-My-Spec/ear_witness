# Anubis.Server.Authorization.WellKnown

Plug serving the RFC 9728 protected resource metadata document.

Responds to `GET /.well-known/oauth-protected-resource` with the JSON
metadata document describing this resource server's OAuth 2.1 configuration.

This plug is automatically handled by both
`Anubis.Server.Transport.StreamableHTTP.Plug` and
`Anubis.Server.Transport.SSE.Plug` when authorization is configured.
It can also be mounted independently in a Phoenix router or Plug pipeline.

## Standalone Usage

    forward "/.well-known/oauth-protected-resource",
      to: Anubis.Server.Authorization.WellKnown,
      authorization_config: my_auth_config