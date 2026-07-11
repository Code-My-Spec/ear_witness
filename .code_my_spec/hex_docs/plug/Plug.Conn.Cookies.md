# Plug.Conn.Cookies

Conveniences for encoding and decoding cookies.

## decode/1

Decodes the given cookies as given in either a request or response header.

If a cookie is invalid, it is automatically discarded from the result.

## Examples

    iex> decode("key1=value1;key2=value2")
    %{"key1" => "value1", "key2" => "value2"}