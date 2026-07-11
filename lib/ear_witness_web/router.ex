defmodule EarWitnessWeb.Router do
  use EarWitnessWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {EarWitnessWeb.LayoutView, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", EarWitnessWeb do
    pipe_through :browser
    live "/", TodoLive
  end
end
