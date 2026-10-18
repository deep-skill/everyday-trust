import Config

config :everyday_trust, EverydayTrust.Repo,
  url:
    System.get_env(
      "TEST_DATABASE_URL",
      "postgres://postgres:local-development-only@db/everyday_trust_test"
    ),
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

config :everyday_trust, EverydayTrustWeb.Endpoint,
  http: [port: 4002],
  server: false,
  secret_key_base: String.duplicate("test-only-", 10)

config :everyday_trust, service_token: "test-service-token"
config :everyday_trust, network_checks: false
config :everyday_trust, test_helpers: true
