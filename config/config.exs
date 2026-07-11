import Config

config :esbuild,
  version: "0.12.18",
  default: [
    args: ~w(js/app.js --bundle --target=es2016 --outdir=../priv/static/assets),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

config :dart_sass,
  version: "1.61.0",
  default: [
    args: ~w(css/app.scss ../priv/static/assets/app.css),
    cd: Path.expand("../assets", __DIR__)
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
  # because of the iOS rebind - this is now a fixed port, but randomly selected
  http: [ip: {127, 0, 0, 1}, port: 10_000 + :rand.uniform(45_000)],
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

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
