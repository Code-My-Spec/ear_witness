# Anubis.Protocol

MCP protocol version management.

Provides version validation, negotiation, feature detection, and transport
compatibility checking. Delegates version-specific logic to modules under
`Anubis.Protocol.*` via `Anubis.Protocol.Registry`.

## Adding a new protocol version

1. Create a new module under `lib/anubis/protocol/` implementing `Anubis.Protocol.Behaviour`
2. Register it in `Anubis.Protocol.Registry`

## validate_version/1

Validates if a protocol version is supported.

## validate_transport/2

Validates if a transport is compatible with a protocol version.

## get_features/1

Returns the set of features supported by a protocol version.

Delegates to the version module's `supported_features/0` callback.

## negotiate_version/2

Negotiates protocol version between client and server versions.

Returns the best compatible version or an error if incompatible.

## compatible_transports/2

Returns transport modules that support a protocol version.

## validate_client_config/3

Validates client configuration for protocol compatibility.

This function checks if the client configuration is compatible with
the specified protocol version, including transport and capabilities.