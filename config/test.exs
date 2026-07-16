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
  # `max_cases: 1` (test_helper.exs) serializes writes within one run;
  # busy_timeout makes a locked connection WAIT up to 30s rather than
  # raising `Database busy` immediately. NOTE: the `:database` path above is
  # overridden per OS process in config/runtime.exs, so concurrent `mix
  # test` invocations (several agents' stop hooks at once) no longer share a
  # file — that, not busy_timeout, is what removes the cross-invocation
  # `Database busy` flake; busy_timeout is now just belt-and-suspenders.
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
  bot_relay: EarWitnessTest.PendingBotRelay,
  # The :announce consent policy plays a real audible notice through the
  # virtual-mic device (EarWitness.Audio.ConsentPolicy). Tests have no such
  # device, so default the delivery seam to success;
  # simulate_announcement_delivery_failure/0 flips it to :fail per test.
  announcement_delivery_override: :ok,
  # Live-transcription spec seam (story 872). Inert unless a spec opts into the
  # `:fixture_live` capture (EarWitnessSpex.Fixtures.enable_live_capture_seam/0):
  # the LiveTranscriber then drains a controllable stand-in instead of the NIF,
  # and only advances when a spec calls `flush` (never on a timer), so live
  # segment streaming is deterministic. See EarWitnessTest.FakeCaptureReader.
  capture_reader: EarWitnessSpex.Fixtures.FakeCaptureReader,
  live_transcriber_drain_interval_ms: :manual

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

# The catalog pins large-v3-turbo's REAL hosted SHA-256, but the cassette
# above replays a small stub body. Override the expected checksum for that
# model with the stub's hash so verification still passes in tests without
# weakening the production checksum (see EarWitness.Models.expected_checksum/1).
config :ear_witness, :model_checksum_overrides, %{
  "large-v3-turbo" => "011c3bdd860284902853c2591486a51f6f193b152c1817a048d97ab624cb8121"
}

# Isolate downloaded models to a temp dir per test partition — the download
# specs write a stub for large-v3-turbo, and without this they'd write it into
# the real ~/Documents/Discussit/models and clobber a genuinely downloaded
# model. EarWitnessTest.DataCase.setup_sandbox/1 empties this before each test
# so a prior test's stub doesn't make Models.downloaded?/1 (which checks the
# file on disk) return true.
config :ear_witness,
       :models_dir,
       Path.join(
         System.tmp_dir!(),
         "ear_witness_test_models#{System.get_env("MIX_TEST_PARTITION")}"
       )

# Print only warnings and errors during test
config :logger, level: :debug
