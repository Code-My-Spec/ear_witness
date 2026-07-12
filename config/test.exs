import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :ear_witness, EarWitnessWeb.Endpoint,
  http: [port: 4002],
  server: false

# A dedicated, gitignored (see `.config/*` in .gitignore) database file per
# test partition, checked out with the Ecto SQL Sandbox so every test's
# changes roll back at the end of the test. Without `pool:
# Ecto.Adapters.SQL.Sandbox` here, `EarWitnessTest.DataCase.setup_sandbox/1`
# (used by every `_test.exs` and every `_spex.exs` via `EarWitnessSpex.Case`)
# fails with `cannot invoke sandbox operation with pool
# DBConnection.ConnectionPool` — the Repo boots with the default pool and
# there is nothing to check a sandboxed connection out of. Keep the default
# `:pool_size` (rather than pinning it to 1): app boot itself (migrations +
# Oban's Lite engine) needs more than one connection available at once, even
# though SQLite only allows a single *writer* transaction at a time — the
# Sandbox/DBConnection layers already serialize writes for us (see the
# ecto_sqlite3 docs' "Async Sandbox testing" caveat re: `async: true`, which
# this project's specs don't use).
config :ear_witness, EarWitness.Repo,
  database: ".config/test/database#{System.get_env("MIX_TEST_PARTITION")}.sq3",
  pool: Ecto.Adapters.SQL.Sandbox,
  # Multiple concurrent `mix test` invocations (several agents' stop hooks
  # firing the suite at once against this shared DB file) collide on
  # SQLite's single-writer lock. `max_cases: 1` serializes within one run;
  # busy_timeout makes a locked connection WAIT up to 30s for the lock
  # instead of raising `Database busy` immediately — absorbing the
  # cross-invocation contention too.
  busy_timeout: 30_000

config :ear_witness, Oban, testing: :inline

# Substitution seams for BDD specs (see .code_my_spec/knowledge/bdd/spex/index.md).
# The engine double replays RECORDED real whisper.cpp responses — never
# hand-written output. Capture uses fixture WAV bytes instead of miniaudio.
# The bot relay has no real meeting to join, so it stays permanently
# pending — specs stage join/record/leave outcomes directly through
# EarWitness.Bots (see EarWitnessSpex.Fixtures.simulate_bot_*/1).
config :ear_witness,
  transcription_engine: EarWitnessTest.RecordedTranscriptionEngine,
  diarizer: EarWitnessTest.RecordedDiarizer,
  capture_source: :fixture,
  bot_relay: EarWitnessTest.PendingBotRelay

# EarWitness.Models.Downloader replays a recorded HTTP interaction instead
# of fetching the real (multi-gigabyte) model file — see the req_cassette
# ADR and test/cassettes/models/large_v3_turbo_download.json (a small
# fixture standing in for the real download). Matching only on method+URI
# (not headers/body) means every attempt against the same URL — including
# retries — replays the same interaction.
# Wrapped in GatedDownloadPlug (transparent pass-through by default) so
# criterion 7368 can hold a transfer genuinely in flight — see that module.
config :ear_witness, EarWitness.Models.Downloader,
  plug: {
    EarWitnessSpex.Fixtures.GatedDownloadPlug,
    %{
      cassette_name: "large_v3_turbo_download",
      cassette_dir: "test/cassettes/models",
      mode: :replay,
      match_requests_on: [:method, :uri]
    }
  }

# Print only warnings and errors during test
config :logger, level: :debug
