import Config

# Port override must live here (not config.exs) so releases honor it at boot.
if port = System.get_env("EARWITNESS_PORT") do
  config :ear_witness, EarWitnessWeb.Endpoint,
    http: [ip: {127, 0, 0, 1}, port: String.to_integer(port)]
end

# CodeMySpec support widget (chat + feedback tabs, server-side Slipstream).
# The deploy key authenticates this install to CodeMySpec; it is generated on
# the project page at codemyspec.com and must never be committed. Without it
# the widget renders but stays disconnected.
if deploy_key = System.get_env("DEPLOY_KEY") do
  config :ear_witness, :deploy_key, deploy_key
end

if widget_url = System.get_env("CODEMYSPEC_WIDGET_URL") do
  config :ear_witness, codemyspec_widget_url: widget_url
end

if email = System.get_env("EARWITNESS_USER_EMAIL") do
  config :ear_witness, :widget_user_email, email
end
