# QA Plan — EarWitness

## App Overview

EarWitness is an elixir-desktop application: the whole Phoenix stack (Phoenix
1.8, LiveView 1.2, Ecto over SQLite via ecto_sqlite3) runs locally inside one
BEAM, with the UI rendered in a native wxWebView window. The endpoint binds
`127.0.0.1:4848` (fixed default; `EARWITNESS_PORT` overrides) and is guarded
by `Desktop.Auth`: a random per-boot login key — the first request must be
`GET /?k=<key>`, which sets a session cookie; everything without that session
gets `401 Unauthorized` (verified: unauthed `/` → 401, login → 200, authed
`/` → 200). One router with a single `:browser` pipeline serving `live "/",
TodoLive` (currently the recording/transcription UI); an `:api` pipeline is
defined but has no routes yet. The CodeMySpec chat widget renders on every
page as `#codemyspec-chat-widget`.

## Tools Registry

### mix run — start the app for QA

Boots the full app (opens the desktop window on this Mac) and prints the
authenticated URL + ready-made curl commands:

    mix run --no-halt priv/repo/qa_server.exs

Output includes `Login URL: http://localhost:4848/?k=<KEY>`. The key rotates
every boot — always start QA sessions from this output.

### curl — HTTP-level checks

Establish the session once, then reuse the cookie jar:

    .code_my_spec/qa/scripts/qa_login.sh <KEY>
    .code_my_spec/qa/scripts/authenticated_curl.sh /

(Equivalent raw commands: `curl -c /tmp/ew_cookies.txt -sS
"http://localhost:4848/?k=<KEY>"` then `curl -b /tmp/ew_cookies.txt
http://localhost:4848/`.) Unauthenticated requests return `401` with body
`Unauthorized` — that response is itself a useful probe that the app is up.

### Vibium — LiveView interaction

Navigate to the Login URL once (sets the session cookie in the browser
context), then drive the UI normally. Real selectors probed from the running
page at `/`:

- Device pickers: `<form phx-change="select_input">` with `select#input-select`
  (name="input"), `<form phx-change="select_output">` with
  `select#output-select` (name="output").
- Recording: buttons pushing events `record` (payload `{input, output}`) and
  `stop`.
- Transcription: per-recording buttons pushing event `transcribe` with value
  `{"recording": "<filename>.raw"}`.
- Todo legacy: `phx-click="toggle"` on items; flash uses
  `phx-click="lv:clear-flash"`.
- Chat/feedback widget: root `#codemyspec-chat-widget` (only connects to
  CodeMySpec when `DEPLOY_KEY` is set; otherwise renders disconnected).

Screenshot destination on this box is UNVERIFIED — before relying on
`browser_screenshot` paths, take one screenshot and check whether the file
lands at the given path or in `~/Pictures/Vibium/<basename>`.

### mix run --no-start — seeds and DB scripts

See Seed Strategy. The `--no-start` flag is mandatory for any script hitting
the DB while the app runs (port/window collision otherwise).

## Seed Strategy

One Repo (`EarWitness.Repo`, SQLite). The database file is created on app
boot at `.config/todo/database.sq3` **relative to the working directory the
app was started from** (quirk documented in System Issues).

- `priv/repo/qa_seeds.exs` — run: `mix run --no-start priv/repo/qa_seeds.exs`.
  Starts only ecto_sqlite3 + the Repo (no window, no endpoint). Idempotently
  creates two todos ("QA seed: pending item" [todo], "QA seed: completed
  item" [done]) and prints the database path. No credentials — the app has
  no user accounts; auth is the per-boot Desktop.Auth key printed by
  `qa_server.exs`.
- `priv/repo/qa_server.exs` — run: `mix run --no-halt priv/repo/qa_server.exs`.
  Not a seed script: boots the app for a QA session and prints the login
  URL/key and curl recipes.
- Recordings for transcription tests: the app lists `.raw` files from
  `~/Documents/Discussit/recordings/`; test fixtures exist in repo at
  `test/fixtures/*.raw` and can be copied there to seed transcribable audio.

As Recordings/Transcription/Speakers contexts land, extend `qa_seeds.exs`
with context-module fixtures (recordings, transcripts) rather than raw
inserts.

## System Issues

### Desktop.Auth key rotates per boot

Every app restart invalidates the previous key and all cookies. QA sessions
must re-read the key from the `qa_server.exs` boot output. Automation that
caches URLs across restarts will get 401s.

### Second `mix run` collides with the running app

`mix run` (without `--no-start`) boots the full desktop app: it fights for
port 4848 and opens a second window. Always use `--no-start` for scripts and
one dedicated `qa_server.exs` instance for the session.

### Database path is cwd-relative

`config :ear_witness, EarWitness.Repo, database: ".config/todo/database.sq3"`
— relative, so app instances started from different directories see
different databases. Start the app and all seed scripts from the project
root. (Candidate future fix: absolute path under `EarWitness.app_dir()`.)

### MCP surface not yet running

The architecture includes `EarWitnessWeb.McpServer` (Anubis) but it is not
implemented yet; there is no MCP transport to probe. When it lands, plain
one-shot curl will NOT work for tool calls (Anubis Streamable HTTP: `202
Accepted` + SSE) — use an MCP-aware client, and re-probe this plan.

## Notes

The UI at `/` is transitional: it is the inherited todo-app LiveView already
extended with recording/transcription controls. The architecture proposal
replaces it with RecordingLive/TranscriptLive/SearchLive/SetupLive/
SettingsLive/BotLive surfaces (Tailwind v4 + DaisyUI now power the CSS
pipeline). Re-probe selectors and update the Tools Registry as each new
surface ships. The desktop window opening during QA is normal — this is a
desktop app; there is no headless server mode today.
