# Kino.Proxy

Functionality for handling proxy requests forwarded from Livebook.

Livebook proxies requests at the following paths:

  * `/proxy/sessions/:id/*path` - a notebook session

  * `/proxy/apps/:slug/sessions/:session_id/*path` - a specific app session

  * `/proxy/apps/:slug/*path` - generic app path, only supported for
    single-session apps. If the app has automatic shutdowns enabled
    and it is not currently running, it will be automatically started

You can define a custom listener to handle requests at these paths.
The listener receives a `Plug.Conn` and it should use the `Plug` API
to send the response, for example:

    Kino.Proxy.listen(fn conn ->
      Plug.Conn.send_resp(conn, 200, "hello")
    end

> #### Plug dependency {: .info}
>
> In order to use this feature, you need to add `:plug` as a dependency.

## Examples

Using the proxy feature, we can use Livebook apps to build APIs.
For example, we could provide a data export endpoint:

    Kino.Proxy.listen(fn
      %{path_info: ["export", "data"]} = conn ->
        data = "some data"

        conn
        |> Plug.Conn.put_resp_header("content-type", "application/csv")
        |> Plug.Conn.send_resp(200, data)

      conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "application/text")
        |> Plug.Conn.send_resp(200, "use /export/data to get extract the report data")
    end)

Once deployed as an app, the API client would be able to export the data
by sending a request to `/apps/:slug/proxy/export/data`.

> #### Authentication {: .warning}
>
> The paths exposed by `Kino.Proxy` don't use the authentication mechanisms
> defined in your Livebook instance.
>
> If you need to authenticate requests, you should
> implement your own authentication mechanism. Here's a simple example.
>
> ```elixir
> Kino.Proxy.listen(fn conn ->
>   expected_token = "my-secret-api-token"
>
>   with ["Bearer " <> user_token] <- Plug.Conn.get_req_header(conn, "authorization"),
>        true <- Plug.Crypto.secure_compare(user_token, expected_token) do
>     Plug.Conn.send_resp(conn, 200, "hello")
>   else
>     _ ->
>       conn
>       |> Plug.Conn.put_resp_header("www-authenticate", "Bearer")
>       |> Plug.Conn.send_resp(401, "Unauthorized")
>   end
> end)
> ```

## Using Plug modules with Kino.Proxy

You can also provide a module plug as an argument to `Kino.Proxy.listen/1`,
like this:

    defmodule MyPlug do
      def init([]), do: false
    
      def call(conn, _opts) do
        Plug.Conn.send_resp(conn, 200, "hello world!")
      end
    end

    Kino.Proxy.listen(MyPlug)

Or a more complex example, using `Plug.Router` to handle multiple endpoints:

    defmodule ApiRouter do
      use Plug.Router
    
      plug :match
      plug :dispatch
    
      get "/hello" do
        send_resp(conn, 200, "hello from router")
      end
    
      get "/echo/:message" do
        send_resp(conn, 200, String.upcase(message))
      end
    
      match _ do
        send_resp(conn, 404, "oops, not found")
      end
    end
    
    Kino.Proxy.listen(ApiRouter)

## listen/1

Registers a request listener.

Expects the listener to be a plug, that is, one of:

  * a function plug: a `fun(conn)` function that takes a `Plug.Conn` and returns a `Plug.Conn`.

  * a module plug: a `module` atom or a `{module, options}` tuple.