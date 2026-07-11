defmodule EarWitnessWeb.Error do
  use EarWitnessWeb, :controller

  @moduledoc """
    Error message module
  """

  def index(conn, _opts) do
    send_resp(conn, 401, "Unauthorized")
  end
end
