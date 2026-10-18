if Mix.env() != :dev || System.get_env("E2E_IDENTITY_MOCK") != "true",
  do: raise("Local test only")

keys = Jason.decode!(File.read!(System.fetch_env!("E2E_JWKS_FILE")))["keys"]
Application.put_env(:everyday_trust, :test_jwks, keys)
Application.put_env(:everyday_trust, :test_identity_delete, fn _ -> :ok end)
File.write!("/tmp/trust-e2e.pid", System.pid())
Process.sleep(:infinity)
