# Anubis.SSE



## connect/3

Connects to a server-sent event stream.

## Parameters

  - `server_url` - the URL of the server to connect to.
  - `headers` - additional headers to send with the request.
  - `opts` - additional options to pass to the HTTP client.

## Examples

    iex> Anubis.SSE.connect("http://localhost:4000")
    #Stream<[ref: 1, task: #PID<0.123.0>]>