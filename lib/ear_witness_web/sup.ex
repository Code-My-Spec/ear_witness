defmodule EarWitnessWeb.Sup do
  use Supervisor

  @moduledoc """
    Supervisor for the WebApp
  """

  def start_link([]) do
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init([]) do
    children = [
      {Phoenix.PubSub, name: EarWitness.PubSub},
      {Registry, keys: :unique, name: EarWitness.CodeMySpec.WidgetRegistry},
      {DynamicSupervisor, strategy: :one_for_one, name: EarWitness.CodeMySpec.WidgetSupervisor},
      EarWitnessWeb.Endpoint,
      EarWitness.Transcription.Server,
      {Oban, Application.fetch_env!(:ear_witness, Oban)}
    ]

    :session = :ets.new(:session, [:named_table, :public, read_concurrency: true])
    Supervisor.init(children, strategy: :one_for_one, max_restarts: 1000)
  end
end
