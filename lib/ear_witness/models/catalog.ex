defmodule EarWitness.Models.Catalog do
  @moduledoc """
  Known transcription models — id, display name, size, quality/language
  tradeoffs, checksum, and download URL. Flags whether each model's file
  ships bundled with the app (no download involved) or must be fetched by
  `EarWitness.Models.Downloader`, and which model id is the recommended
  default.

  Two real whisper.cpp/ggml model tiers, per story 866:

    * `"large-v3-turbo"` — best accuracy, the recommended default. Not
      bundled (a ~1.6GB file); `EarWitness.Models.Downloader` fetches it on
      first use. The download URL is the real upstream location and the
      checksum is the real hosted file's SHA-256 (HuggingFace's
      `X-Linked-Etag` / git-LFS oid for `ggml-large-v3-turbo.bin`), so a
      real download verifies in production. Tests replay a small stub body
      via `ReqCassette`, so `config/test.exs` overrides this model's
      expected checksum with the stub's hash
      (`:ear_witness, :model_checksum_overrides`) — see
      `EarWitness.Models` and `EarWitness.Models.Downloader`.
    * `"base"` — English-only, smaller and faster. Ships bundled at
      `models/ggml-base.en.bin` (repo root, fetched by `make
      models/ggml-base.en.bin` — see `.code_my_spec/devops/setup.md`), so
      nothing to download or verify.
  """

  @type model :: %{
          id: String.t(),
          name: String.t(),
          description: String.t(),
          size_bytes: pos_integer(),
          bundled: boolean(),
          default: boolean(),
          download_url: String.t() | nil,
          checksum: String.t() | nil
        }

  @models [
    %{
      id: "large-v3-turbo",
      name: "Large v3 Turbo",
      description: "Best accuracy across languages and accents. Recommended for most hearings.",
      size_bytes: 1_624_555_275,
      bundled: false,
      default: true,
      download_url:
        "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo.bin",
      checksum: "1fc70f774d38eb169993ac391eea357ef47c88757ef72ee5943879b7e8e2bc69"
    },
    %{
      id: "base",
      name: "Base (English)",
      description: "Smaller and faster, English only. Ships with the app — nothing to download.",
      size_bytes: 147_964_211,
      bundled: true,
      default: false,
      download_url: nil,
      checksum: nil
    }
  ]

  @doc "Lists every known model, in catalog order."
  @spec list_models() :: [model()]
  def list_models, do: @models

  @doc "Looks up a single catalog entry by id, or `nil` when unknown."
  @spec get_model(String.t()) :: model() | nil
  def get_model(id), do: Enum.find(@models, &(&1.id == id))

  @doc "The id of the catalog's recommended default model."
  @spec default_model_id() :: String.t()
  def default_model_id, do: Enum.find(@models, & &1.default).id

  @doc """
  The id of the always-available bundled model — the fallback the app
  auto-activates when no model has been explicitly chosen yet, so a fresh
  install can transcribe immediately without a forced setup step.
  """
  @spec bundled_model_id() :: String.t()
  def bundled_model_id, do: Enum.find(@models, & &1.bundled).id

  @doc """
  The absolute path a bundled model's file is shipped at.

  Prefers the canonical per-user models directory (`EarWitness.models_dir()`,
  an absolute app-data path) so the packaged app resolves the base model
  regardless of the process's working directory. Falls back to the
  cwd-relative repo-root `models/` location, which is where the file lives in
  a dev checkout (`make models/ggml-base.en.bin`).
  """
  @spec bundled_path(model()) :: String.t()
  def bundled_path(%{id: "base", bundled: true}) do
    data_dir_path = Path.join(EarWitness.models_dir(), "ggml-base.en.bin")

    if File.exists?(data_dir_path) do
      data_dir_path
    else
      Path.join([File.cwd!(), "models", "ggml-base.en.bin"])
    end
  end
end
