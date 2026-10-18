defmodule EverydayTrust.Urlscan.Cache do
  use GenServer

  @success_ttl 21_600_000
  @error_ttl 60_000

  def start_link(options \\ []), do: GenServer.start_link(__MODULE__, options, name: __MODULE__)
  def reserve(host), do: GenServer.call(__MODULE__, {:reserve, host})
  def complete(host, token, result), do: GenServer.call(__MODULE__, {:complete, host, token, result})

  @impl true
  def init(_), do: {:ok, %{entries: %{}, pending: %{}}}

  @impl true
  def handle_call({:reserve, host}, _from, state) do
    now = System.monotonic_time(:millisecond)
    state = %{
      entries: Map.reject(state.entries, fn {_, {expires, _}} -> expires <= now end),
      pending: Map.reject(state.pending, fn {_, {expires, _}} -> expires <= now end)
    }

    case state.entries[host] do
      {_, result} ->
        {:reply, {:cached, result}, state}

      _ ->
        if Map.has_key?(state.pending, host) or map_size(state.pending) >= 3 do
          {:reply, :busy, state}
        else
          token = make_ref()
          {:reply, {:reserved, token}, put_in(state, [:pending, host], {now + 31_000, token})}
        end
    end
  end

  @impl true
  def handle_call({:complete, host, token, result}, _from, state) do
    state =
      case state.pending[host] do
        {_, ^token} ->
          ttl = if result["status"] in ["matched", "no_match"], do: @success_ttl, else: @error_ttl

          %{
            entries: Map.put(state.entries, host, {System.monotonic_time(:millisecond) + ttl, result}),
            pending: Map.delete(state.pending, host)
          }

        _ ->
          state
      end

    {:reply, :ok, state}
  end
end

defmodule EverydayTrust.Urlscan do
  alias EverydayTrust.{Cases, Destination, Domain, Signals}
  alias EverydayTrust.Urlscan.Cache

  @endpoint "https://urlscan.io/api/v1/scan/"
  @source "https://urlscan.io/"
  @deadline 30_000
  @test_helpers Application.compile_env(:everyday_trust, :test_helpers, false)

  def enabled?, do: Application.get_env(:everyday_trust, :urlscan_enabled, false) == true

  def check(raw) do
    uri = sanitize_url(raw)
    key = Application.get_env(:everyday_trust, :urlscan_api_key)

    cond do
      not enabled?() -> result(nil, "disabled")
      is_nil(uri) -> result(nil, "blocked")
      not is_binary(key) or key == "" -> result(uri.host, "unavailable")
      true -> cached_scan(uri, key)
    end
  rescue
    _ -> result(nil, "unavailable")
  catch
    _, _ -> result(nil, "unavailable")
  end

  def enrich(original, urls) do
    candidates =
      urls
      |> Enum.map(&sanitize_url/1)
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq_by(& &1.host)
      |> Enum.take(5)

    checks =
      if enabled?() do
        candidates
        |> Task.async_stream(&check(URI.to_string(&1)),
          max_concurrency: 5,
          timeout: deadline() + 100,
          on_timeout: :kill_task
        )
        |> Enum.zip(candidates)
        |> Enum.map(fn
          {{:ok, checked}, _} -> checked
          {_, uri} -> result(uri.host, "timeout")
        end)
      else
        []
      end

    coverage =
      cond do
        not enabled?() -> "disabled"
        candidates == [] -> "not_applicable"
        Enum.all?(checks, &(&1["status"] in ["matched", "no_match"])) -> "completed"
        Enum.any?(checks, &(&1["status"] in ["matched", "no_match"])) -> "partial"
        Enum.all?(checks, &(&1["status"] == "budget_exhausted")) -> "budget_exhausted"
        true -> "unavailable"
      end

    enriched =
      original
      |> put_in(["coverage", "urlscan"], coverage)
      |> Map.put("url_scans", checks)

    matches = Enum.filter(checks, &(&1["status"] == "matched"))

    if matches == [] do
      enriched
    else
      signal = %{
        "id" => "urlscan_malicious",
        "severity" => "high",
        "domain" => hd(matches)["domain"],
        "domains" => matches |> Enum.map(& &1["domain"]) |> Enum.reject(&is_nil/1) |> Enum.uniq(),
        "message" => "La navegación aislada de urlscan encontró indicios de una página engañosa. Verifica por un canal oficial antes de actuar.",
        "source" => @source,
        "checked_at" => hd(matches)["checked_at"]
      }

      enriched
      |> Map.update!("signals", &Enum.uniq_by(&1 ++ [signal], fn item -> item["id"] end))
      |> Map.put("verdict", "high_risk")
      |> Map.put("risk_origin", "external_signal")
      |> Map.put("summary", "Una comprobación externa encontró indicios de engaño en el sitio. No lo abras y verifica por un canal oficial.")
      |> Map.update!("rules_score", &min(100, &1 + 45))
    end
  end

  def sanitize_url(raw) when is_binary(raw) and byte_size(raw) <= 8_192 do
    with %URI{scheme: scheme, host: host, port: port} = uri <- Signals.parse(raw),
         true <- (scheme == "https" and port == 443) or (scheme == "http" and port == 80),
         true <- allowed_host?(host),
         false <- String.contains?(raw, ["\r", "\n", "\t", "\\"]) do
      %{uri | userinfo: nil, query: nil, fragment: nil, path: uri.path || "/"}
    else
      _ -> nil
    end
  end

  def sanitize_url(_), do: nil

  defp allowed_host?(host) do
    if byte_size(host) > 253 do
      false
    else
      case :inet.parse_address(String.to_charlist(host)) do
        {:ok, ip} -> Destination.public_ip?(ip)
        _ ->
          String.contains?(host, ".") and
            not String.ends_with?(host, [".localhost", ".local", ".internal"]) and
            Enum.all?(String.split(host, "."), &Regex.match?(~r/^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$/, &1))
      end
    end
  end

  defp cached_scan(uri, key) do
    case Cache.reserve(uri.host) do
      {:cached, checked} -> Map.put(checked, "cached", true)
      :busy -> result(uri.host, "unavailable")
      {:reserved, token} ->
        checked =
          if reserve_quota() do
            task = Task.async(fn -> scan(uri, key) end)

            case Task.yield(task, deadline()) || Task.shutdown(task, :brutal_kill) do
              {:ok, checked} -> checked
              _ -> result(uri.host, "timeout")
            end
          else
            result(uri.host, "budget_exhausted")
          end

        Cache.complete(uri.host, token, checked)
        checked
    end
  end

  defp reserve_quota do
    if @test_helpers and is_function(Application.get_env(:everyday_trust, :test_urlscan_quota), 0),
      do: Application.get_env(:everyday_trust, :test_urlscan_quota).(),
      else: Cases.quota("global", nil, "urlscan", 300)
  end

  defp scan(uri, key) do
    with {:ok, %{"uuid" => uuid, "visibility" => visibility}} <-
           request(:post, @endpoint, key, %{"url" => URI.to_string(uri), "visibility" => "unlisted"}),
         {:ok, uuid} <- Ecto.UUID.cast(uuid),
         true <- visibility in ["unlisted", "private"] do
      wait(10_000)
      poll(uri.host, uuid, key, 0)
    else
      _ -> result(uri.host, "unavailable")
    end
  rescue
    _ -> result(uri.host, "unavailable")
  catch
    _, _ -> result(uri.host, "unavailable")
  end

  defp poll(host, uuid, key, attempt) do
    case request(:get, "https://urlscan.io/api/v1/result/#{uuid}/", key, nil) do
      {:ok, body} -> parse_result(host, uuid, body)
      {:pending, 404} when attempt < 3 ->
        wait(5_000)
        poll(host, uuid, key, attempt + 1)
      {:pending, 404} -> result(host, "timeout")
      _ -> result(host, "unavailable")
    end
  end

  defp parse_result(host, uuid, body) do
    with %{"task" => %{"visibility" => visibility}, "page" => page, "verdicts" => verdicts} <- body,
         true <- visibility in ["unlisted", "private"],
         true <- is_map(page) and is_map(verdicts),
         own when is_map(own) <- Map.get(verdicts, "urlscan"),
         malicious when is_boolean(malicious) <- own["malicious"],
         %URI{host: final_host} <- sanitize_url(page["url"]) do
      result(host, if(malicious, do: "matched", else: "no_match"))
      |> Map.merge(%{
        "final_hostname" => final_host,
        "page_title" => plain(page["title"], 160),
        "brands" => brands(own["brands"]),
        "report_url" => "https://urlscan.io/result/#{uuid}/",
        "visibility" => visibility,
        "scanned_at" => date(get_in(body, ["task", "time"])),
        "scope" => "domain_snapshot"
      })
    else
      _ -> result(host, "unavailable")
    end
  end

  defp brands(values) when is_list(values) do
    values
    |> Enum.take(5)
    |> Enum.map(fn
      %{"name" => name} -> plain(name, 80)
      _ -> nil
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp brands(_), do: []
  defp plain(value, maximum) when is_binary(value), do: value |> String.replace(~r/[\x00-\x1F\x7F]/u, " ") |> String.slice(0, maximum)
  defp plain(_, _), do: nil

  defp date(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, parsed, _} -> DateTime.to_iso8601(parsed)
      _ -> nil
    end
  end

  defp date(_), do: nil

  defp result(host, status),
    do: %{"hostname" => host, "domain" => if(host, do: Domain.registrable_domain(host)), "status" => status, "checked_at" => DateTime.to_iso8601(DateTime.utc_now()), "source" => @source}

  defp wait(milliseconds) do
    if @test_helpers and is_function(Application.get_env(:everyday_trust, :test_urlscan_wait), 1),
      do: Application.get_env(:everyday_trust, :test_urlscan_wait).(milliseconds),
      else: Process.sleep(milliseconds)
  end

  defp deadline do
    value = if @test_helpers, do: Application.get_env(:everyday_trust, :test_urlscan_deadline), else: nil
    if is_integer(value) and value > 0 and value <= @deadline, do: value, else: @deadline
  end

  defp request(method, url, key, body) do
    options = [
      method: method,
      url: url,
      headers: [{"api-key", key}, {"accept", "application/json"}, {"user-agent", "EverydayTrust/0.1"}],
      redirect: false,
      retry: false,
      compressed: false,
      decode_body: false,
      receive_timeout: 1_500,
      pool_timeout: 500,
      connect_options: [timeout: 700],
      into: &collect/2
    ]

    options = if body, do: Keyword.put(options, :json, body), else: options

    response =
      if @test_helpers and is_function(Application.get_env(:everyday_trust, :test_urlscan_request), 1),
        do: Application.get_env(:everyday_trust, :test_urlscan_request).(options),
        else: Req.request(options)

    case response do
      {:ok, %{status: 200, body: value}} when is_binary(value) and byte_size(value) <= 2_000_000 -> Jason.decode(value)
      {:ok, %{status: 404}} -> {:pending, 404}
      _ -> {:error, :unavailable}
    end
  end

  defp collect({:data, chunk}, {request, response}) do
    body = response.body || ""

    if byte_size(body) + byte_size(chunk) <= 2_000_000,
      do: {:cont, {request, %{response | body: body <> chunk}}},
      else: {:halt, {request, %{response | status: 502, body: ""}}}
  end
end
