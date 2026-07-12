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
      first use. The download URL below is the real upstream location; the
      checksum is pinned to the small stand-in artifact this project
      currently tests against (`test/fixtures/models/large-v3-turbo-stub.bin`)
      rather than a real 1.6GB file's checksum — update both together once
      the app ships a real hosted copy.
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
      checksum: "011c3bdd860284902853c2591486a51f6f193b152c1817a048d97ab624cb8121"
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

  @doc "The absolute path a bundled model's file is shipped at."
  @spec bundled_path(model()) :: String.t()
  def bundled_path(%{id: "base", bundled: true}) do
    Path.join([File.cwd!(), "models", "ggml-base.en.bin"])
  end
end
