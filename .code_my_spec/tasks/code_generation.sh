#!/bin/bash
# Code generation script — produced by CodeMySpec code_generation task
# Re-run on a fresh copy of this project to reproduce the scaffold.
#
# EarWitness is a single-user, local-first desktop app (ADRs:
# local-first-privacy, elixir-desktop, desktop-distribution). The standard
# auth/multi-tenancy/OAuth generators (phx.gen.auth, cms_gen.accounts,
# cms_gen.integrations, cms_gen.integration_provider) are intentionally NOT
# run — there are no user accounts. Per operator decision (2026-07-11), the
# CodeMySpec support widget (chat + feedback tabs) IS included; it uses a
# deploy key over server-side Slipstream, no OAuth required.

set -e

# CodeMySpec support widget: chat + feedback (server-side Slipstream client,
# sticky nested LiveView). Post-gen wiring applied in-repo: slipstream dep,
# WidgetRegistry + WidgetSupervisor in EarWitnessWeb.Sup, live_render in
# root.html.heex, Widget.local_user/0 desktop identity (no auth scope),
# config in config.exs + runtime.exs (DEPLOY_KEY env), html-to-image npm dep.
mix client_utils.gen.chat_widget
