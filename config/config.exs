import Config

config :esbuild,
  version: "0.12.18",
  default: [
    args: ~w(js/app.js --bundle --target=es2016 --outdir=../priv/static/assets),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

config :tailwind,
  version: "4.1.7",
  default: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/app.css
    ),
    cd: Path.expand("..", __DIR__)
  ]

config :logger,
  handle_otp_reports: true,
  handle_sasl_reports: false,
  backends: [:console]

config :logger, :console,
  level: :notice,
  metadata: [:request_id]

# Configures the endpoint
config :ear_witness, EarWitnessWeb.Endpoint,
  # Fixed, predictable default so QA tooling and MCP clients can find the app;
  # override with EARWITNESS_PORT (e.g. for the iOS rebind case or collisions).
  http: [
    ip: {127, 0, 0, 1},
    port: String.to_integer(System.get_env("EARWITNESS_PORT") || "4848")
  ],
  render_errors: [view: EarWitnessWeb.ErrorView, accepts: ~w(html json), layout: false],
  pubsub_server: EarWitness.PubSub,
  live_view: [signing_salt: "sWpG9ljX"],
  secret_key_base: :crypto.strong_rand_bytes(32),
  server: true

config :phoenix, :json_library, Jason

config :ear_witness,
  ecto_repos: [EarWitness.Repo]

# We're defining this at runtime
config :ear_witness, EarWitness.Repo, database: ".config/todo/database.sq3"

config :ear_witness, Oban,
  engine: Oban.Engines.Lite,
  queues: [default: 10],
  repo: EarWitness.Repo

# CodeMySpec support widget (chat + feedback). The deploy key and any
# user-facing email are supplied at runtime — see config/runtime.exs.
# Without a deploy key the widget client stays disconnected (no-op).
config :ear_witness,
  codemyspec_widget_url: "wss://codemyspec.com/widget"

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
