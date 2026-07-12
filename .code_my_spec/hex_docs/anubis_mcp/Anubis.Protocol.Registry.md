# Anubis.Protocol.Registry

Registry for MCP protocol version modules.

Maps version strings to their implementing modules, supports version negotiation,
and provides the central dispatch point for version-specific protocol logic.

## Usage

    iex> Anubis.Protocol.Registry.get("2025-11-25")
    {:ok, Anubis.Protocol.V2025_11_25}

    iex> Anubis.Protocol.Registry.supported_versions()
    ["2025-11-25", "2025-06-18", "2025-03-26", "2024-11-05"]

    iex> Anubis.Protocol.Registry.negotiate("2025-03-26")
    {:ok, "2025-03-26", Anubis.Protocol.V2025_03_26}

## get/1

Get the protocol module for a given version string.

## Examples

    iex> Anubis.Protocol.Registry.get("2025-06-18")
    {:ok, Anubis.Protocol.V2025_06_18}

    iex> Anubis.Protocol.Registry.get("unknown")
    :error

## supported_versions/0

List all supported versions in preference order (newest first).

## latest_version/0

Returns the latest supported protocol version string.

## fallback_version/0

Returns the fallback protocol version for compatibility.

## latest_module/0

Returns the module for the latest supported protocol version.

## supported?/1

Check if a version string is supported.

## negotiate/1

Negotiate the best version given a client's requested version.

MCP spec: the server picks the version, the client proposes one.
If we support the requested version, use it. Otherwise, return an error
with the list of supported versions.

## Examples

    iex> Anubis.Protocol.Registry.negotiate("2025-11-25")
    {:ok, "2025-11-25", Anubis.Protocol.V2025_11_25}

    iex> Anubis.Protocol.Registry.negotiate("9999-01-01")
    {:error, :unsupported_version, ["2025-11-25", "2025-06-18", "2025-03-26", "2024-11-05"]}

## negotiate/2

Negotiate version between client and server supported version lists.

Used when the server has a restricted set of supported versions.
Returns the best matching version (client's preference if in server list,
otherwise server's latest).

## Examples

    iex> Anubis.Protocol.Registry.negotiate("2025-03-26", ["2025-11-25", "2025-03-26"])
    {:ok, "2025-03-26", Anubis.Protocol.V2025_03_26}

    iex> Anubis.Protocol.Registry.negotiate("2024-11-05", ["2025-11-25", "2025-03-26"])
    {:ok, "2025-11-25", Anubis.Protocol.V2025_11_25}

## get_features/1

Returns the features supported by a given version.

Delegates to the version module's `supported_features/0` callback.

## supports_feature?/2

Checks if a feature is supported by a protocol version.

## progress_params_schema/1

Returns the progress notification params schema for a given version.

Delegates to the version module's `progress_params_schema/0` callback.