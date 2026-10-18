defmodule EverydayTrust.AccessTest do
  use ExUnit.Case, async: false
  import Plug.Test
  import Plug.Conn
  @issuer "https://cognito-idp.us-east-1.amazonaws.com/us-east-1_test"
  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(EverydayTrust.Repo)
    key = JOSE.JWK.generate_key({:rsa, 2048})
    {_, public} = JOSE.JWK.to_public_map(key)
    Application.put_env(:everyday_trust, :test_jwks, [Map.put(public, "kid", "test-key")])
    Application.put_env(:everyday_trust, :cognito_issuer, @issuer)
    Application.put_env(:everyday_trust, :cognito_client_id, "test-client")
    Application.put_env(:everyday_trust, :test_identity_delete, fn _ -> :ok end)

    on_exit(fn ->
      for k <- [:test_jwks, :cognito_issuer, :cognito_client_id, :test_identity_delete],
          do: Application.delete_env(:everyday_trust, k)
    end)

    %{key: key}
  end

  defp token(key, overrides \\ %{}) do
    now = System.system_time(:second)

    claims =
      Map.merge(
        %{
          "iss" => @issuer,
          "sub" => "synthetic-subject",
          "client_id" => "test-client",
          "token_use" => "access",
          "exp" => now + 3600,
          "auth_time" => now
        },
        overrides
      )

    {_, value} =
      JOSE.JWT.sign(key, %{"alg" => "RS256", "kid" => "test-key"}, claims) |> JOSE.JWS.compact()

    value
  end

  defp request(method, path, bearer \\ nil, body \\ %{}) do
    c =
      conn(method, path, Jason.encode!(body))
      |> put_req_header("content-type", "application/json")
      |> put_req_header("accept", "application/json")
      |> put_req_header("x-service-token", "test-service-token")
      |> put_req_header("x-session-id", String.duplicate("a", 64))

    c = if bearer, do: put_req_header(c, "authorization", "Bearer " <> bearer), else: c
    EverydayTrustWeb.Endpoint.call(c, EverydayTrustWeb.Endpoint.init([]))
  end

  test "verified Cognito access token grants account access", %{key: key} do
    assert request(:get, "/api/v1/me", token(key)).status == 200
  end

  for override <- [
        %{"exp" => 1},
        %{"client_id" => "wrong-client"},
        %{"iss" => "https://other.example"},
        %{"token_use" => "id"}
      ] do
    test "rejects invalid claims #{inspect(override)}", %{key: key} do
      assert request(:get, "/api/v1/me", token(key, unquote(Macro.escape(override)))).status ==
               401
    end
  end

  test "missing and malformed identity cannot read history" do
    assert request(:get, "/api/v1/history").status == 401
    assert request(:get, "/api/v1/history", "invalid.token").status == 401
  end

  test "API rejects requests without its BFF service credential" do
    result =
      conn(:post, "/api/v1/cases", Jason.encode!(%{text: "Hola"}))
      |> put_req_header("content-type", "application/json")
      |> EverydayTrustWeb.Endpoint.call(EverydayTrustWeb.Endpoint.init([]))

    assert result.status == 401
  end

  test "input validation and request body cap run on the API" do
    assert request(:post, "/api/v1/cases", nil, %{text: ""}).status == 400

    assert request(:post, "/api/v1/cases", nil, %{text: String.duplicate("a", 5001)}).status ==
             413
  end

  test "account deletion removes data and blocks still-signed access tokens", %{key: key} do
    bearer = token(key)
    created = request(:post, "/api/v1/cases", bearer, %{text: "Un mensaje sintético"})
    assert created.status == 201
    id = Jason.decode!(created.resp_body)["id"]
    assert request(:post, "/api/v1/cases/#{id}/save", bearer).status == 200
    assert request(:delete, "/api/v1/me", bearer).status == 200
    assert EverydayTrust.Repo.aggregate(EverydayTrust.SavedCase, :count) == 0
    assert request(:get, "/api/v1/history", bearer).status == 403
  end

  test "account deletion needs recent authentication", %{key: key} do
    assert request(
             :delete,
             "/api/v1/me",
             token(key, %{"auth_time" => System.system_time(:second) - 600})
           ).status == 403
  end
end
