import Config

# Release-safe logging.
#
# A packaged desktop app is launched with no controlling terminal (e.g. by
# double-clicking the .app), so Erlang's default logger handler — which writes
# to standard_io/standard_error — crashes on its first write with
# "the device does not exist". During boot that badarg terminates the whole
# runtime (see the "Runtime terminating during boot" crash on first stderr
# write). Route logs to a rotating file under the user's log directory instead,
# which also gives distributed installs somewhere to look when something breaks.
#
# Guarded to releases (RELEASE_NAME is only set there) so `mix phx.server` /
# `iex -S mix` in development keep their normal console output.
if System.get_env("RELEASE_NAME") do
  home = System.user_home!() || System.tmp_dir!()

  log_dir =
    case :os.type() do
      {:unix, :darwin} -> Path.join([home, "Library", "Logs", "EarWitness"])
      {:win32, _} -> Path.join([home, "AppData", "Local", "EarWitness", "Logs"])
      _ -> Path.join([home, ".local", "state", "ear_witness", "logs"])
    end

  File.mkdir_p!(log_dir)

  config :logger, :default_handler,
    config: [
      file: String.to_charlist(Path.join(log_dir, "ear_witness.log")),
      max_no_bytes: 5_000_000,
      max_no_files: 5
    ]
end

# Port override must live here (not config.exs) so releases honor it at boot.
if port = System.get_env("EARWITNESS_PORT") do
  config :ear_witness, EarWitnessWeb.Endpoint,
    http: [ip: {127, 0, 0, 1}, port: String.to_integer(port)]
end

# CodeMySpec support widget (chat + feedback tabs, server-side Slipstream).
# The deploy key authenticates this install to CodeMySpec; it is generated on
# the project page at codemyspec.com and must never be committed. Without it
# the widget renders but stays disconnected.
if deploy_key = System.get_env("DEPLOY_KEY") do
  config :ear_witness, :deploy_key, deploy_key
end

if widget_url = System.get_env("CODEMYSPEC_WIDGET_URL") do
  config :ear_witness, codemyspec_widget_url: widget_url
end

if email = System.get_env("EARWITNESS_USER_EMAIL") do
  config :ear_witness, :widget_user_email, email
end

# Give each concurrent `mix test` OS process its OWN SQLite file, so separate
# suite runs (several agents' stop hooks firing the suite at once) never
# contend on SQLite's single-writer lock — the intermittent `Exqlite.Error:
# Database busy` that `busy_timeout` and `max_cases: 1` only partly absorb.
#
# This must live in runtime.exs, not config/test.exs: a compile-time path is
# baked into the shared `_build`, so two concurrent runs that skip
# recompilation would reuse the same file and still collide. Evaluated at boot,
# `System.pid()` is this run's OS process id — unique across concurrent runs.
# Only `:database` is overridden; the pool/busy_timeout from config/test.exs
# still apply. Files land in the OS temp dir (auto-reaped, no repo clutter).
if config_env() == :test do
  partition = System.get_env("MIX_TEST_PARTITION") || ""

  config :ear_witness, EarWitness.Repo,
    database: Path.join(System.tmp_dir!(), "ear_witness_test_#{partition}_#{System.pid()}.sq3")
end
