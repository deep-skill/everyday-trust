defmodule EverydayTrust.Identity.Keys do
  use GenServer
  def start_link(_), do: GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  def init(_), do: {:ok, %{keys: [], fetched: System.monotonic_time(:second) - 3601}}
  def get(kid), do: GenServer.call(__MODULE__, {:get, kid}, 5_000)

  def handle_call({:get, kid}, _, state) do
    now = System.monotonic_time(:second)
    configured = Application.get_env(:everyday_trust, :test_jwks)

    state =
      cond do
        configured ->
          %{keys: configured, fetched: now}

        now - state.fetched > 3600 ||
            (now - state.fetched > 30 && !Enum.any?(state.keys, &(&1["kid"] == kid))) ->
          refresh(state, now)

        true ->
          state
      end

    {:reply, Enum.find(state.keys, &(&1["kid"] == kid)), state}
  end

  defp refresh(state, now) do
    issuer = Application.get_env(:everyday_trust, :cognito_issuer)

    if is_binary(issuer) &&
         Regex.match?(
           ~r/^https:\/\/cognito-idp\.[a-z0-9-]+\.amazonaws\.com\/[A-Za-z0-9_-]+$/,
           issuer
         ) do
      case Req.get(issuer <> "/.well-known/jwks.json",
             redirect: false,
             retry: false,
             receive_timeout: 2_000,
             connect_options: [timeout: 1_000]
           ) do
        {:ok, %{status: 200, body: %{"keys" => keys}}} when is_list(keys) ->
          %{keys: keys, fetched: now}

        _ ->
          %{keys: [], fetched: now}
      end
    else
      %{state | fetched: now}
    end
  end
end

defmodule EverydayTrust.Identity do
  def verify(token) do
    issuer = Application.get_env(:everyday_trust, :cognito_issuer)
    client = Application.get_env(:everyday_trust, :cognito_client_id)

    with true <- is_binary(issuer) && is_binary(client) && byte_size(token) < 8192,
         %JOSE.JWS{fields: %{"kid" => kid}} <- JOSE.JWT.peek_protected(token),
         key when not is_nil(key) <- EverydayTrust.Identity.Keys.get(kid),
         {true, %JOSE.JWT{fields: claims}, _} <-
           JOSE.JWT.verify_strict(JOSE.JWK.from_map(key), ["RS256"], token),
         true <-
           claims["iss"] == issuer && claims["client_id"] == client &&
             claims["token_use"] == "access",
         expiry when is_integer(expiry) <- claims["exp"],
         true <- expiry > System.system_time(:second),
         true <-
           !claims["nbf"] ||
             (is_integer(claims["nbf"]) && claims["nbf"] <= System.system_time(:second)),
         subject when is_binary(subject) and byte_size(subject) > 0 <- claims["sub"] do
      {:ok, %{issuer: issuer, subject: subject, auth_time: claims["auth_time"], token: token}}
    else
      _ -> {:error, :unauthorized}
    end
  rescue
    _ -> {:error, :unauthorized}
  catch
    _, _ -> {:error, :unauthorized}
  end
end
