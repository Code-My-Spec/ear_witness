import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :ear_witness, EarWitnessWeb.Endpoint,
  http: [port: 4002],
  server: false

config :ear_witness, Oban, testing: :inline

# Substitution seams for BDD specs (see .code_my_spec/knowledge/bdd/spex/index.md).
# The engine double replays RECORDED real whisper.cpp responses — never
# hand-written output. Capture uses fixture WAV bytes instead of portaudio.
config :ear_witness,
  transcription_engine: EarWitnessTest.RecordedTranscriptionEngine,
  capture_source: :fixture

# Print only warnings and errors during test
config :logger, level: :debug
