import Config

# For development, we disable any cache and enable
# debugging and code reloading.
#
# The watchers configuration can be used to run external
# watchers to your application. For example, we use it
# with esbuild to recompile .js and .css sources.
config :ear_witness, EarWitnessWeb.Endpoint,
  debug_errors: true,
  code_reloader: true,
  check_origin: false,
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:default, ~w(--sourcemap=inline --watch)]},
    tailwind: {Tailwind, :install_and_run, [:default, ~w(--watch)]}
  ],
  # Watch static and templates for browser reloading.
  live_reload: [
    patterns: [
      ~r"priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"priv/gettext/.*(po)$",
      ~r"lib/ear_witness/.*(ee?x)$",
      ~r"lib/ear_witness_web/(live|views)/.*(ex)$",
      ~r"lib/ear_witness_web/templates/.*(eex)$"
    ]
  ]

# Do not include metadata nor timestamps in development logs
config :logger, :console, format: "[$level] $message\n", level: :notice

# Set a higher stacktrace during development. Avoid configuring such
# in production as building large stacktraces may be expensive.
config :phoenix, :stacktrace_depth, 20

# Initialize plugs at runtime for faster development compilation
config :phoenix, :plug_init_mode, :runtime

# Local, gitignored dev secrets (e.g. the CodeMySpec widget :deploy_key for
# local issue reporting). Create config/dev.secret.exs to enable the widget in
# dev; it's matched by config/*.secret.exs in .gitignore and never committed.
if File.exists?("config/dev.secret.exs") do
  import_config "dev.secret.exs"
end
