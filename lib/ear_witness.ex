defmodule EarWitness do
  @moduledoc """
    EarWitness Application. This module takes care of the the boot.
    Because the EarWitness is a standalone desktop application there is
    initial Database initialization needed when the SQlite database is
    not yet existing. This is done during start() by
    calling `EarWitness.Repo.initialize()`.

    Other than that this module initialized the main `Desktop.Window`
    and configures it to create a taskbar icon as well.

  """
  use Application

  def config_dir(), do: Path.join([Desktop.OS.home(), ".config", "discussit"])
  def app_dir(), do: Path.join([Desktop.OS.home(), "Documents", "Discussit"])
  def recordings_dir(), do: Path.join(app_dir(), "recordings")
  def binaries_dir(), do: Path.join([:code.priv_dir(:ear_witness), "binaries"])
  def transcription_id(), do: Path.join(app_dir(), "transcripts")

  @app Mix.Project.config()[:app]

  def start(:normal, []) do
    Desktop.identify_default_locale(EarWitnessWeb.Gettext)
    File.mkdir_p!(config_dir())
    File.mkdir_p!(app_dir())
    File.mkdir_p!(recordings_dir())
    File.mkdir_p!(transcription_id())

    {:ok, sup} = Supervisor.start_link([EarWitness.Repo], name: __MODULE__, strategy: :one_for_one)
    EarWitness.Repo.initialize()

    {:ok, _} = Supervisor.start_child(sup, EarWitnessWeb.Sup)

    {:ok, _} =
      Supervisor.start_child(sup, {
        Desktop.Window,
        [
          app: @app,
          id: EarWitnessWindow,
          title: "EarWitness",
          size: {600, 500},
          icon: "icon.png",
          menubar: EarWitness.MenuBar,
          icon_menu: EarWitness.Menu,
          url: &EarWitnessWeb.Endpoint.url/0
        ]
      })
  end

  def config_change(changed, _new, removed) do
    EarWitnessWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
