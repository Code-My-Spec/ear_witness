# EarWitness: Desktop-Native DevOps + Live Support Widget (2026-07-11)

Two milestones today, both shaped by the same fact: EarWitness is not a web
app, and pretending otherwise wastes money.

**DevOps, desktop edition.** The standard server loadout (Hetzner box,
Cloudflare DNS, TLS, Postgres, secrets store) is formally recorded as
not-applicable. There is no server: "production" is a signed installer on the
user's machine, built by elixir-desktop's deployment tooling from the same
Mix release. Backups are the user's own machine backups — by design, the app
never ships data off-device. Possible side quest brewing: hardening the
elixir-desktop release/installer story and contributing it back upstream to
the maintainer.

**Support without surveillance.** EarWitness now has a built-in chat +
feedback widget connected to CodeMySpec — but wired for a desktop app:

- The app's *server side* (running locally in the BEAM) opens one Slipstream
  websocket authenticated by a deploy key. No OAuth, no accounts, and the
  key never reaches the browser layer.
- No auth system exists, so identity is a per-install UUID persisted in the
  config dir — the operator sees a stable anonymous user unless the person
  opts into setting their email.
- Feedback tab supports optional screenshots (html-to-image); chat tab talks
  to a live operator.
- Without a deploy key configured, the widget quietly stays disconnected —
  the app works fully offline, keeping the local-first promise.

All tests green. Auth, multi-tenancy, and OAuth scaffolds were deliberately
skipped — a single-user local app needs none of them.
