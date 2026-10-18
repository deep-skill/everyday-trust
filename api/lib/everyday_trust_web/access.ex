defmodule EverydayTrustWeb.Access do
  import Plug.Conn
  def init(options), do: options

  def call(conn, _) do
    expected = Application.fetch_env!(:everyday_trust, :service_token)
    actual = get_req_header(conn, "x-service-token") |> List.first() || ""
    session = get_req_header(conn, "x-session-id") |> List.first() || ""
    network = get_req_header(conn, "x-network-id") |> List.first() || session
    conn = assign(conn, :network, network)

    if byte_size(actual) == byte_size(expected) && Plug.Crypto.secure_compare(actual, expected) &&
         Regex.match?(~r/^[a-f0-9]{64}$/, session) do
      case get_req_header(conn, "authorization") do
        [] ->
          assign(conn, :owner, nil) |> assign(:session, session)

        ["Bearer " <> token] ->
          case EverydayTrust.Identity.verify(token) do
            {:ok, identity} ->
              blocked = EverydayTrust.Accounts.blocked?(identity)

              if blocked && !(conn.method == "DELETE" && conn.request_path == "/api/v1/me") do
                reject(conn, 403)
              else
                assign(conn, :owner, if(!blocked, do: EverydayTrust.Cases.profile(identity)))
                |> assign(:session, session)
                |> assign(:identity, identity)
              end

            _ ->
              reject(conn, 401)
          end

        _ ->
          reject(conn, 401)
      end
    else
      reject(conn, 401)
    end
  end

  defp reject(conn, status),
    do:
      conn
      |> put_resp_content_type("application/json")
      |> send_resp(
        status,
        Jason.encode!(%{error: %{code: "unauthorized", message: "Inicia sesión para continuar."}})
      )
      |> halt()
end
