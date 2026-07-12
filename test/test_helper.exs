# The Repo boots (via `mix test`'s automatic `app.start`) before this file
# runs, so the target directory for the test-only SQLite file
# (config/test.exs) must already exist — exqlite does not create
# intermediate directories itself.
File.mkdir_p!(Path.join([File.cwd!(), ".config", "test"]))

ExUnit.start()

# `EarWitnessTest.DataCase.setup_sandbox/1` (used by every `_test.exs` and,
# via `EarWitnessSpex.Case`, every `_spex.exs`) checks a sandboxed
# connection out per test. `:manual` mode is what makes that checkout
# meaningful — without it the Repo stays in the default `:auto` sandbox
# mode and every connection shares the same (uncontrolled) transaction.
Ecto.Adapters.SQL.Sandbox.mode(EarWitness.Repo, :manual)
