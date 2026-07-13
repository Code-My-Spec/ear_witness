defmodule EarWitnessWeb.Application do
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

  @app Mix.Project.config()[:app]

  def start(:normal, []) do
    Desktop.identify_default_locale(EarWitnessWeb.Gettext)
    File.mkdir_p!(EarWitness.config_dir())
    File.mkdir_p!(EarWitness.app_dir())
    File.mkdir_p!(EarWitness.recordings_dir())
    File.mkdir_p!(EarWitness.transcription_id())
    File.mkdir_p!(EarWitness.models_dir())

    {:ok, sup} =
      Supervisor.start_link([EarWitness.Repo], name: __MODULE__, strategy: :one_for_one)

    EarWitness.Repo.initialize()
    # Bring the schema up before anything that queries it (the LiveView pages,
    # Oban) starts — releases have no separate `mix ecto.migrate` step.
    EarWitness.Repo.migrate()

    if mcp_stdio_mode?() do
      # Launched by an AI assistant as a stdio MCP subprocess (see the
      # anubis-mcp ADR, story 868). Serve ONLY the read-mostly tool surface
      # over stdin/stdout — no Phoenix endpoint (a second listener would
      # clash with a running GUI instance) and no desktop window. The tools
      # reach the same on-disk SQLite DB through Repo, which is already up.
      #
      # Gated on an env var because Anubis's stdio transport always starts
      # and `{:stop, :normal}`s on stdin EOF: a normal GUI/test/QA boot has
      # no attached client, so its dead stdin would EOF-loop the transport.
      # An MCP client's launch command sets EARWITNESS_MCP_STDIO; see
      # priv/mcp/earwitness.mcp.json.example.
      {:ok, _} = Supervisor.start_child(sup, {EarWitnessWeb.McpServer.Server, transport: :stdio})
      {:ok, sup}
    else
      {:ok, _} = Supervisor.start_child(sup, EarWitnessWeb.Sup)

      {:ok, _} =
        Supervisor.start_child(sup, {
          Desktop.Window,
          [
            app: @app,
            id: EarWitnessWindow,
            title: "EarWitness",
            size: {1200, 850},
            icon: "icon.png",
            menubar: EarWitness.MenuBar,
            icon_menu: EarWitness.Menu,
            url: &EarWitnessWeb.Endpoint.url/0
          ]
        })

      {:ok, sup}
    end
  end

  # An AI assistant's MCP client sets this when it launches EarWitness as a
  # stdio subprocess; everyday GUI/test/QA boots leave it unset and never
  # start the stdio transport.
  defp mcp_stdio_mode?, do: System.get_env("EARWITNESS_MCP_STDIO") in ~w(1 true yes)

  def config_change(changed, _new, removed) do
    EarWitnessWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
