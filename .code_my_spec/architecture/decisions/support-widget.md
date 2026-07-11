# CodeMySpec support widget over deploy-key Slipstream

## Status
Accepted

## Context
The founder wants in-app chat and feedback (screenshots included) from
dogfooding users back to the CodeMySpec operator — without adding accounts,
OAuth, or a meeting-bot-style privacy violation to a local-first app.

## Decision
Use the CodeMySpec support widget (`mix client_utils.gen.chat_widget`,
already generated and wired): a sticky nested LiveView whose *server-side*
Slipstream websocket authenticates with the project deploy key
(`DEPLOY_KEY` env → `config :ear_witness, :deploy_key`). No OAuth, no user
accounts; identity is a per-install UUID (`Widget.local_user/0`) persisted
in the config dir, with an optional operator-facing email via
`EARWITNESS_USER_EMAIL`.

## Consequences
- This is the one sanctioned network channel carrying user-initiated
  content off-device (support messages and screenshots the user explicitly
  submits) — an explicit exception under the local-first-privacy ADR.
- Without a deploy key configured the widget stays disconnected and the app
  is fully offline.
- Adds `slipstream` (+ mint_web_socket) and the `html-to-image` npm package.
