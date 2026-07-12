defmodule EarWitnessWeb.Endpoint do
  use Desktop.Endpoint, otp_app: :ear_witness

  # The session will be stored in the cookie and signed,
  # this means its contents can be read but not tampered with.
  # Set :encryption_salt if you would also like to encrypt it.
  @session_options [
    store: :ets,
    key: "_todo_key",
    table: :session
  ]

  socket "/socket", EarWitnessWeb.UserSocket,
    websocket: true,
    longpoll: false

  socket "/live", Phoenix.LiveView.Socket, websocket: [connect_info: [session: @session_options]]

  plug Plug.Static,
    at: "/",
    from: :ear_witness,
    gzip: false,
    only: ~w(assets fonts images favicon.ico robots.txt)

  # Code reloading can be explicitly enabled under the
  # :code_reloader configuration of your endpoint.
  if code_reloading? do
    socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket
    plug Phoenix.LiveReloader
    plug Phoenix.CodeReloader
  end

  plug Plug.RequestId

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head

  plug Plug.Session, @session_options

  # Desktop.Auth gates every request behind a per-BEAM-run random key
  # (`Desktop.Auth.login_key/0`), only ever known to the launched
  # Desktop.Window webview — real browser/test clients have no way to
  # obtain it. BDD specs (`test/spex/**/*_spex.exs`) and any future
  # ExUnit tests drive routes with a plain `Phoenix.ConnTest.build_conn()`,
  # so this plug is skipped in :test; every other env keeps the real check.
  unless Mix.env() == :test do
    plug Desktop.Auth
  end

  plug EarWitnessWeb.Router
end
