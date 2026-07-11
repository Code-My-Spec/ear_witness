defmodule EarWitnessSpex.Case do
  @moduledoc """
  Base case for spex (BDD spec) tests.

  Wires up Phoenix.ConnTest for HTTP assertions, Phoenix.LiveViewTest
  for driving LiveViews, the SexySpex DSL (spex/scenario/given_/when_/then_),
  and the DB sandbox.
  """
  use ExUnit.CaseTemplate

  using do
    quote do
      @endpoint EarWitnessWeb.Endpoint

      use EarWitnessWeb, :verified_routes
      use SexySpex

      import Plug.Conn
      import Phoenix.ConnTest
      import Phoenix.LiveViewTest
      import EarWitnessSpex.Case
    end
  end

  setup tags do
    EarWitnessTest.DataCase.setup_sandbox(tags)
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end
end
