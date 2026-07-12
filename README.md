# EarWitness

A desktop app that listens, transcribes, and figures out who said what — entirely on your machine. No audio ever leaves your computer.

Built with Elixir and LiveView by [Code My Spec](https://codemyspec.com/).

## How it works

EarWitness runs as a native desktop app ([elixir-desktop](https://github.com/elixir-desktop/desktop)) with a native capture pipeline behind it:

1. **Capture** — a [miniaudio](https://github.com/mackron/miniaudio) C NIF streams raw audio from any input device (and, on Windows/Linux, system-output loopback).
2. **Voice activity detection** — [Silero VAD](https://github.com/snakers4/silero-vad) (ONNX, via [Ortex](https://github.com/elixir-nx/ortex)) splits the stream into utterances and drops silence.
3. **Transcription** — a [whisper.cpp](https://github.com/ggml-org/whisper.cpp) NIF transcribes recordings locally.
4. **Speaker change detection** *(in progress)* — the [pyannote segmentation-3.0](https://huggingface.co/pyannote/segmentation-3.0) model scores per-speaker activity over sliding windows; peak detection over the change scores marks speaker boundaries.
5. **Speaker clustering & identification** *(planned)* — speaker embeddings + clustering to label who said what.

Transcripts land as plain text files in `~/Documents/Discussit/transcripts`.

## Requirements

- Erlang/OTP 29 and Elixir 1.20 (see `.tool-versions`; both via [asdf](https://asdf-vm.com/))
- cmake and a C++ compiler (for whisper.cpp and the NIF)
- npm (for assets)

> **macOS + wxWidgets note:** elixir-desktop needs Erlang built with wx support, and OTP's wx bindings do not build against wxWidgets 3.3 (what Homebrew ships). Build wxWidgets 3.2.x from source with `--enable-compat30`, then build Erlang with `--with-wx-config` pointing at it:
>
> ```bash
> export KERL_CONFIGURE_OPTIONS="--without-javac --with-ssl=$(brew --prefix openssl@3) --with-wx-config=$HOME/.local/wxwidgets-3.2.9/bin/wx-config"
> asdf install
> ```

## Setup

```bash
# Elixir deps
mix deps.get

# whisper.cpp (cloned + built at a pinned tag) and the NIF
mix compile

# Whisper model (~148 MB, not in git)
make models/ggml-base.en.bin

# Assets
(cd assets && npm install)
mix assets.deploy

# Secrets — copy and fill in (only needed for the gated pyannote models)
cp .env.example .env
```

## Run

```bash
mix phx.server
```

A desktop window opens with the recorder UI. Recordings are transcribed in the background and deleted once their transcript is written.

```bash
mix test
```

## Project layout

| Path | What |
|---|---|
| `lib/ear_witness/audio/` | Live capture: miniaudio NIF wrapper, capture pipeline, consent policy |
| `lib/ear_witness/signals/` | Peak detection over speaker-change scores |
| `lib/ear_witness/transcription/` | GenServer driving the whisper.cpp NIF |
| `lib/ear_witness_web/` | Phoenix/LiveView UI shown in the desktop webview |
| `c_src/ear_witness/` | Transcription NIF (whisper.cpp is cloned here by `make`, not committed) |
| `priv/models/` | Silero VAD and pyannote segmentation ONNX models |
| `segmentation.livemd` | Livebook for exploring the segmentation model output |

---

Made by [Code My Spec](https://codemyspec.com/).
