# Anubis.Client.Request



## new/1

Creates a new request struct.

## Parameters

  * `attrs` - Map containing the request attributes
    * `:id` - The unique request ID
    * `:method` - The MCP method name
    * `:from` - The GenServer caller reference
    * `:timer_ref` - Reference to the request-specific timeout timer

## elapsed_time/1

Calculates the elapsed time for a request in milliseconds.