import Config

# 0.12's --watch polls ancestor directories (node_modules resolution) all
# the way to $HOME, so ANY file write anywhere near the repo triggered a
# rebuild -> priv/static write -> live-reload -> every open page remounts.
# In practice that was a continuous reload storm (and the wxWebView's
# NSURLErrorCancelled -999 spam). Modern esbuild watches only real inputs.
config :esbuild,
  version: "0.25.4",
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

# No :backends key — it is deprecated and, on Elixir 1.20, setting it
# silently disables the default handler entirely (no console logs at all,
# which hid LiveView crash reports in dev).
config :logger,
  handle_otp_reports: true,
  handle_sasl_reports: false

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
  # Transcription is its own single-slot queue: each whisper run loads a full
  # model, and concurrent runs have taken the whole machine down. The Gate
  # (EarWitness.Transcription.Gate) additionally serializes against the live
  # transcriber, which doesn't go through Oban.
  queues: [default: 10, transcription: 1],
  repo: EarWitness.Repo

# Transcription engine / diarizer / capture device / bot relay seams
# (see .code_my_spec/knowledge/bdd/spex/index.md). Test env overrides
# all four to the recorded/fixture/pending doubles in config/test.exs.
config :ear_witness,
  transcription_engine: EarWitness.Transcription.Engine,
  diarizer: EarWitness.Speakers.Diarizer.Onnx,
  capture_source: :miniaudio,
  bot_relay: EarWitness.Bots.Runner.Relay

# CodeMySpec support widget (chat + feedback). The deploy key and any
# user-facing email are supplied at runtime — see config/runtime.exs.
# Without a deploy key the widget client stays disconnected (no-op).
config :ear_witness,
  codemyspec_widget_url: "wss://codemyspec.com/widget"

# EarWitnessWeb.McpServer (see the anubis-mcp ADR, story 868) — stdio
# transport ONLY. No :port key here, ever: the "no network listener for
# assistant access" guarantee (criterion 7382) is structural, verified by
# reading this exact config back.
config :ear_witness, EarWitnessWeb.McpServer, transport: :stdio

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
