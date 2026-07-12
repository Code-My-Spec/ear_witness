# The Repo boots (via `mix test`'s automatic `app.start`) before this file
# runs, so the target directory for the test-only SQLite file
# (config/test.exs) must already exist — exqlite does not create
# intermediate directories itself.
File.mkdir_p!(Path.join([File.cwd!(), ".config", "test"]))

# SQLite permits only one writer at a time, so running test cases
# concurrently makes them contend for the DB lock and intermittently raise
# `Exqlite.Error: Database busy` (especially the LiveView specs, which each
# do several writes per scenario). Serialize by default — the whole suite
# runs in ~2s serially, and this removes the flake without needing every
# invocation to pass `--max-cases 1`.
ExUnit.start(max_cases: 1)

# `EarWitnessTest.DataCase.setup_sandbox/1` (used by every `_test.exs` and,
# via `EarWitnessSpex.Case`, every `_spex.exs`) checks a sandboxed
# connection out per test. `:manual` mode is what makes that checkout
# meaningful — without it the Repo stays in the default `:auto` sandbox
# mode and every connection shares the same (uncontrolled) transaction.
Ecto.Adapters.SQL.Sandbox.mode(EarWitness.Repo, :manual)
