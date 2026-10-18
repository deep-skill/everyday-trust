import Config

config :everyday_trust, ecto_repos: [EverydayTrust.Repo]

config :everyday_trust, EverydayTrustWeb.Endpoint,
  adapter: Bandit.PhoenixAdapter,
  render_errors: [formats: [json: EverydayTrustWeb.ErrorJSON], layout: false],
  pubsub_server: EverydayTrust.PubSub

config :phoenix, :json_library, Jason

config :phoenix, :filter_parameters, [
  "text",
  "message",
  "authorization",
  "token",
  "code",
  "password"
]

config :logger, level: :warning

import_config "#{config_env()}.exs"
