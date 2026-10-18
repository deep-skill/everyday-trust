import Config

config :everyday_trust, EverydayTrust.Repo,
  url:
    System.get_env(
      "DATABASE_URL",
      "postgres://postgres:local-development-only@db/everyday_trust_dev"
    ),
  pool_size: 5

config :everyday_trust, EverydayTrustWeb.Endpoint,
  http: [ip: {0, 0, 0, 0}, port: 4000],
  server: false,
  secret_key_base: String.duplicate("local-development-only-", 4)

config :everyday_trust,
  service_token: System.get_env("API_SERVICE_TOKEN", "local-development-service-token-only")
