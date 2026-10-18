import Config

if System.get_env("PHX_SERVER") == "true",
  do: config(:everyday_trust, EverydayTrustWeb.Endpoint, server: true)

if config_env() == :prod do
  ca = System.fetch_env!("DATABASE_CA_FILE")
  host = URI.parse(System.fetch_env!("DATABASE_URL")).host

  config :everyday_trust, EverydayTrust.Repo,
    url: System.fetch_env!("DATABASE_URL"),
    pool_size: 5,
    ssl: [
      verify: :verify_peer,
      cacertfile: ca,
      server_name_indication: String.to_charlist(host),
      customize_hostname_check: [match_fun: :public_key.pkix_verify_hostname_match_fun(:https)]
    ]

  config :everyday_trust, EverydayTrustWeb.Endpoint,
    http: [ip: {0, 0, 0, 0}, port: 4000],
    secret_key_base: System.fetch_env!("SECRET_KEY_BASE")

  token = System.fetch_env!("API_SERVICE_TOKEN")
  if byte_size(token) < 32, do: raise("API_SERVICE_TOKEN must contain at least 32 bytes")
  System.fetch_env!("COGNITO_ISSUER")
  System.fetch_env!("COGNITO_CLIENT_ID")

  if System.get_env("AI_PROVIDER") == "meta" && System.get_env("AI_INPUT_MODE") != "full_context",
    do: raise("The internal Meta pilot requires AI_INPUT_MODE=full_context")

  config :everyday_trust, service_token: token
end

config :everyday_trust,
  cognito_issuer: System.get_env("COGNITO_ISSUER"),
  cognito_client_id: System.get_env("COGNITO_CLIENT_ID"),
  ai_provider: System.get_env("AI_PROVIDER", "disabled"),
  ai_data_approved: System.get_env("AI_DATA_APPROVED") == "true",
  ai_key:
    System.get_env("MODEL_API_KEY") ||
      if(System.get_env("AI_PROVIDER") == "deepseek", do: System.get_env("DEEPSEEK_API_KEY")),
  network_checks: config_env() != :test && System.get_env("NETWORK_CHECKS", "true") == "true"
