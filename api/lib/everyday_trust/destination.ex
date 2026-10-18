defmodule EverydayTrust.Destination do
  alias EverydayTrust.Signals

  def check(uri), do: follow(uri, [], 0)

  def public_ip?({a, b, c, d})
      when a in 0..255 and b in 0..255 and c in 0..255 and d in 0..255 do
    a not in [0, 10, 127] and a < 224 and
      not (a == 100 and b in 64..127) and
      not (a == 169 and b == 254) and
      not (a == 172 and b in 16..31) and
      not (a == 192 and (b == 168 or (b == 0 and c in [0, 2]) or (b == 88 and c == 99))) and
      not (a == 198 and (b in [18, 19] or (b == 51 and c == 100))) and
      not (a == 203 and b == 0 and c == 113)
  end

  def public_ip?(_), do: false

  defp follow(uri, hosts, hops) do
    cond do
      not allowed?(uri) ->
        result("blocked", hosts)

      uri.host in hosts ->
        result("completed", hosts)

      hops >= 3 ->
        result("partial", hosts)

      true ->
        hosts = hosts ++ [uri.host]

        with {:ok, addresses} <- resolve(uri.host),
             true <- addresses != [] and Enum.all?(addresses, &public_ip?/1),
             {:ok, status, location} <- head(uri, hd(addresses)) do
          if status in [301, 302, 303, 307, 308] and is_binary(location) do
            case Signals.parse(URI.to_string(URI.merge(uri, location))) do
              nil -> result("partial", hosts)
              %URI{scheme: "http"} when uri.scheme == "https" -> result("partial", hosts)
              next -> follow(next, hosts, hops + 1)
            end
          else
            result("completed", hosts)
          end
        else
          false -> result("blocked", hosts)
          {:error, :nxdomain} -> result("not_found", hosts)
          _ -> result("unavailable", hosts)
        end
    end
  rescue
    _ -> result("unavailable", hosts)
  end

  defp result(status, hosts), do: %{status: status, hosts: hosts}

  defp allowed?(%URI{scheme: scheme, host: host, port: port, userinfo: nil})
       when is_binary(host) do
    ((scheme == "https" and port == 443) or (scheme == "http" and port == 80)) and
      not String.contains?(host, ["\r", "\n", "\t", "\\", "%", ":"]) and
      host != "localhost" and not String.ends_with?(host, [".localhost", ".local", ".internal"])
  end

  defp allowed?(_), do: false

  defp resolve(host) do
    case Application.get_env(:everyday_trust, :test_destination_dns) do
      fun when is_function(fun, 1) -> fun.(host)
      _ -> :inet.getaddrs(String.to_charlist(host), :inet)
    end
  end

  defp head(uri, ip) do
    origin = %{uri | path: "/", query: nil, fragment: nil}

    case Application.get_env(:everyday_trust, :test_destination_head) do
      fun when is_function(fun, 2) -> fun.(origin, ip)
      _ -> request(origin, ip)
    end
  end

  defp request(uri, ip) do
    scheme = if uri.scheme == "https", do: :https, else: :http
    transport = [timeout: 700, send_timeout: 700, send_timeout_close: true]

    transport =
      if scheme == :https,
        do: Keyword.put(transport, :cacerts, :public_key.cacerts_get()),
        else: transport

    with {:ok, conn} <-
           Mint.HTTP.connect(scheme, ip, uri.port,
             hostname: uri.host,
             protocols: [:http1],
             mode: :passive,
             log: false,
             max_header_list_size: 16_384,
             transport_opts: transport
           ) do
      try do
        with {:ok, conn, ref} <-
               Mint.HTTP.request(
                 conn,
                 "HEAD",
                 "/",
                 [{"user-agent", "EverydayTrust/0.1"}, {"connection", "close"}],
                 nil
               ) do
          receive_headers(conn, ref, System.monotonic_time(:millisecond) + 900, nil)
        else
          _ -> {:error, :unavailable}
        end
      after
        Mint.HTTP.close(conn)
      end
    end
  end

  defp receive_headers(conn, ref, deadline, status) do
    remaining = deadline - System.monotonic_time(:millisecond)

    if remaining <= 0 do
      {:error, :timeout}
    else
      case Mint.HTTP.recv(conn, 0, remaining) do
        {:ok, next, responses} ->
          status =
            Enum.find_value(responses, status, fn
              {:status, ^ref, code} -> code
              _ -> nil
            end)

          headers =
            Enum.find_value(responses, fn
              {:headers, ^ref, values} -> values
              _ -> nil
            end)

          if headers && status && status >= 200 do
            location =
              Enum.find_value(headers, fn {key, value} -> if key == "location", do: value end)

            {:ok, status, location}
          else
            receive_headers(next, ref, deadline, status)
          end

        _ ->
          {:error, :unavailable}
      end
    end
  end
end
