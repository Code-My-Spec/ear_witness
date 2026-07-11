# EarWitness: QA Infrastructure + Tailwind Switch (2026-07-11)

Two more pieces landed.

**QA that respects the desktop.** EarWitness isn't a web app you curl from
anywhere — elixir-desktop guards the local endpoint with a per-boot login
key so only the app's own webview (or someone holding the key) can connect.
The QA plan now documents the real flow, all verified live: fixed port 4848
(no more random ports), a `qa_server.exs` boot script that prints the
authenticated URL, cookie-jar curl scripts, real LiveView selectors probed
from the running page, and idempotent seed scripts that don't accidentally
boot a second desktop window. Fun findings: the chat widget renders on every
page, and the "legacy" todo UI is already sprouting record/transcribe
controls.

**Tailwind v4 + DaisyUI 5.** The SCSS pipeline is gone. CSS now builds
through the Tailwind standalone CLI with DaisyUI as a vendored plugin — no
node build step — with the old styles kept alive in a legacy import until
each surface gets rebuilt properly. The support widget's DaisyUI markup
went from unstyled to styled in one build.

Also new in the ADR set: Anubis for the upcoming local MCP server, the
support-widget decision record, and the asset-pipeline switch.
