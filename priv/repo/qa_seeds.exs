# QA seeds — run with:
#
#     mix run --no-start priv/repo/qa_seeds.exs
#
# IMPORTANT: the --no-start flag is required. A plain `mix run` boots the
# whole desktop app (Desktop.Window + endpoint), which collides with an
# already-running instance on port 4848 and opens a second window. This
# script starts only the Repo.
#
# Idempotent: safe to re-run. Seeds the current domain (todos — the legacy
# UI still shipping while the recording/transcription surfaces are built).
# As the Recordings/Transcription contexts land, extend this script with
# recording + transcript fixtures using the context modules.

{:ok, _} = Application.ensure_all_started(:ecto_sqlite3)
{:ok, _} = EarWitness.Repo.start_link()

alias EarWitness.{Repo, Todo}

seed_todos = [
  %{text: "QA seed: pending item", status: "todo"},
  %{text: "QA seed: completed item", status: "done"}
]

for attrs <- seed_todos do
  case Repo.get_by(Todo, text: attrs.text) do
    nil ->
      Repo.insert!(struct(Todo, attrs))
      IO.puts("created: #{attrs.text} [#{attrs.status}]")

    _existing ->
      IO.puts("exists:  #{attrs.text}")
  end
end

IO.puts("\nDatabase: #{Application.get_env(:ear_witness, EarWitness.Repo)[:database]}")
IO.puts("Open the app UI (see qa_server.exs output for the authenticated URL).")
