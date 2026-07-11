# EarWitness: CodeMySpec Project Setup Complete (2026-07-11)

EarWitness (the Elixir Desktop transcription app) is now fully wired into the
CodeMySpec spec-driven development workflow. Highlights:

- Application module moved to the web namespace (`EarWitnessWeb.Application`),
  fixing the boundary violation where the core app supervised the web endpoint.
  Filesystem path helpers stayed in `EarWitness` for the domain code.
- Added the CodeMySpec toolchain: client_utils, sexy_spex (BDD specs),
  boundary (module dependency enforcement), sobelow, credo custom checks,
  and code_my_spec_generators.
- Per-environment compiler pipeline with :diagnostics and :boundary compilers,
  plus elixir_make for the whisper.cpp native code.
- New test architecture: `EarWitnessTest` and `EarWitnessSpex` boundaries,
  `EarWitnessTest.ConnCase`/`ChannelCase`/`DataCase`, and a SexySpex-powered
  `EarWitnessSpex.Case` for Given/When/Then BDD specs against LiveView.
- AGENTS.md, CLAUDE.md, 19 default rule files, and credo check scaffolding
  installed.

All 3 existing tests pass (whisper.cpp transcription still green). Two
framework issues filed along the way: install_rules :enoent (stale server)
and a missing compile.spex mix task.

Next up: walking the requirement graph to build out the product.
