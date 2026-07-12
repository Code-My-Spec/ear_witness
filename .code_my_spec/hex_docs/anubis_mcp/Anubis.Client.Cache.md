# Anubis.Client.Cache



## put_tool_validators/2

Stores tool output validators in the cache.
Clears existing validators before storing new ones.

## get_tool_validator/2

Gets a tool output validator from the cache.

## clear_tool_validators/1

Clears all tool validators from the cache.

## cleanup/1

Cleans up all cache tables for a client process.
Should be called when the client process terminates.