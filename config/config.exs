import Config

# On Linux, Membrane's precompiled portaudio binary links libmpdec.so.4 (absent
# on most distros, including the Ubuntu build runner), which breaks release
# packaging when deployment resolves NIF dependencies. Build the portaudio NIF
# against the system library (pkg-config) instead. macOS keeps the precompiled
# binary, which works there. Evaluated on the build machine at compile time, so
# it only affects Linux builds.
if :os.type() == {:unix, :linux} do
  config :bundlex, :disable_precompiled_os_deps, apps: [:membrane_portaudio_plugin]
end

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

# Transcription engine / diarizer / capture device / bot relay seams
# (see .code_my_spec/knowledge/bdd/spex/index.md). Test env overrides
# all four to the recorded/fixture/pending doubles in config/test.exs.
config :ear_witness,
  transcription_engine: EarWitness.Transcription.Engine,
  diarizer: EarWitness.Speakers.Diarizer.Onnx,
  capture_source: :portaudio,
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
