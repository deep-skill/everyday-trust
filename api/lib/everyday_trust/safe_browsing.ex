defmodule EverydayTrust.SafeBrowsing do
  use GenServer

  alias EverydayTrust.{Domain, Signals}

  @endpoint "https://safebrowsing.googleapis.com/v5/urls:search"
  @source "Google Safe Browsing"
  @advisory "https://developers.google.com/safe-browsing/v4/advisory"
  @deadline 1_500
  @cache_seconds 3_600
  @warning_seconds 1_800
  @cache_limit 10_000
  @test_helpers Application.compile_env(:everyday_trust, :test_helpers, false)

  def start_link(options \\ []), do: GenServer.start_link(__MODULE__, options, name: __MODULE__)

  def enabled?, do: Application.get_env(:everyday_trust, :safe_browsing_enabled, false) == true

  def check(urls) when is_list(urls) do
    urls =
      urls
      |> Enum.map(&sanitize_url/1)
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()
      |> Enum.take(5)

    key = Application.get_env(:everyday_trust, :safe_browsing_api_key)

    cond do
      not enabled?() -> response("disabled", [])
      urls == [] -> response("not_applicable", [])
      not is_binary(key) or key == "" -> response("unavailable", [])
      true -> bounded_check(urls, key)
    end
  rescue
    _ -> response("unavailable", [])
  catch
    :exit, _ -> response("unavailable", [])
  end

  def enrich(result, urls) do
    checked = check(urls)
    result = put_in(result, ["coverage", "safe_browsing"], checked.status)

    if checked.signals == [] do
      result
    else
      result
      |> Map.update!("signals", &Enum.uniq_by(&1 ++ checked.signals, fn signal -> signal["id"] end))
      |> Map.put("verdict", "high_risk")
      |> Map.put("risk_origin", "external_signal")
      |> Map.put(
        "summary",
        "Google advierte que uno de los enlaces podría ser peligroso. No lo abras y verifica por un canal oficial."
      )
      |> Map.update!("rules_score", &min(100, &1 + 45))
    end
  end

  def sanitize_url(raw) when is_binary(raw) do
    case Signals.parse(raw) do
      %URI{scheme: scheme, host: host} = uri
      when scheme in ["https", "http"] and is_binary(host) ->
        if byte_size(raw) <= 8_192 and not String.contains?(host, ["\r", "\n", "\t", "\\"]) do
          URI.to_string(%{uri | userinfo: nil, query: nil, fragment: nil, path: uri.path || "/"})
        end

      _ ->
        nil
    end
  end

  def sanitize_url(_), do: nil

  @impl true
  def init(_), do: {:ok, %{}}

  @impl true
  def handle_call({:get, hash, now}, _from, state) do
    case Map.get(state, hash) do
      {expires, check} when expires > now -> {:reply, {:ok, check}, state}
      _ -> {:reply, :miss, Map.delete(state, hash)}
    end
  end

  @impl true
  def handle_call({:put, values, now}, _from, state) do
    state = Map.reject(state, fn {_, {expires, _}} -> expires <= now end)

    state =
      Enum.reduce(values, state, fn {hash, seconds, checked}, cache ->
        if map_size(cache) < @cache_limit or Map.has_key?(cache, hash),
          do: Map.put(cache, hash, {now + seconds * 1_000, checked}),
          else: cache
      end)

    {:reply, :ok, state}
  end

  defp bounded_check(urls, key) do
    task =
      Task.async(fn ->
        try do
          check_urls(urls, key)
        rescue
          _ -> response("unavailable", [])
        catch
          _, _ -> response("unavailable", [])
        end
      end)

    case Task.yield(task, @deadline) || Task.shutdown(task, :brutal_kill) do
      {:ok, checked} -> checked
      _ -> response("unavailable", [])
    end
  end

  defp check_urls(urls, key) do
    now = monotonic_now()
    cached = Enum.map(urls, &{&1, cache_get(hash(&1), now)})
    missing = for {url, :miss} <- cached, do: url

    fresh = if missing == [], do: %{}, else: fetch(missing, key)

    checks =
      Enum.map(cached, fn
        {_, {:ok, checked}} -> checked
        {url, :miss} -> Map.get(fresh, hash(url), check_result(url, "unavailable"))
      end)

    status =
      cond do
        Enum.all?(checks, &(&1["status"] == "unavailable")) -> "unavailable"
        Enum.any?(checks, &(&1["status"] == "unavailable")) -> "partial"
        true -> "completed"
      end

    response(status, checks)
  end

  defp fetch(urls, key) do
    task = Task.async(fn -> request(urls, key) end)

    case Task.yield(task, @deadline - 100) || Task.shutdown(task, :brutal_kill) do
      {:ok, {:ok, body}} -> parse_response(urls, body)
      _ -> %{}
    end
  end

  defp request(urls, key) do
    options = [
      params: Enum.map(urls, &{"urls", &1}),
      headers: [{"x-goog-api-key", key}, {"accept", "application/json"}],
      redirect: false,
      retry: false,
      receive_timeout: @deadline,
      connect_options: [timeout: 700],
      decode_body: false
    ]

    response =
      case if(@test_helpers,
             do: Application.get_env(:everyday_trust, :test_safe_browsing_request),
             else: nil
           ) do
        fun when is_function(fun, 2) -> fun.(@endpoint, options)
        _ -> Req.get(@endpoint, options)
      end

    case response do
      {:ok, %{status: 200, body: body}} when is_binary(body) and byte_size(body) <= 65_536 ->
        Jason.decode(body)

      _ ->
        {:error, :unavailable}
    end
  rescue
    _ -> {:error, :unavailable}
  catch
    _, _ -> {:error, :unavailable}
  end

  defp parse_response(urls, %{"cacheDuration" => duration} = body) do
    threats = Map.get(body, "threats", [])

    with seconds when is_integer(seconds) and seconds > 0 <- duration_seconds(duration),
         true <- is_list(threats) and length(threats) <= 500,
         true <- Enum.all?(threats, &valid_threat?/1) do
      values =
        Enum.map(urls, fn url ->
          matched = Enum.any?(threats, &matches?(url, &1["url"]))
          status = if matched, do: "matched", else: "no_match"
          ttl = if matched, do: min(seconds, @warning_seconds), else: min(seconds, @cache_seconds)
          {hash(url), ttl, check_result(url, status)}
        end)

      cache_put(values, monotonic_now())
      Map.new(values, fn {key, _seconds, checked} -> {key, checked} end)
    else
      _ -> %{}
    end
  end

  defp parse_response(_, _), do: %{}

  defp valid_threat?(%{"url" => url, "threatTypes" => types}),
    do: is_binary(url) and is_list(types) and types != [] and Enum.all?(types, &is_binary/1)

  defp valid_threat?(_), do: false

  defp matches?(url, threat_url) do
    requested = Signals.parse(url)
    threat = Signals.parse(threat_url)

    requested && threat && requested.scheme == threat.scheme &&
      (requested.host == threat.host or String.ends_with?(requested.host, "." <> threat.host)) &&
      path_matches?(requested.path || "/", threat.path || "/")
  end

  defp path_matches?(requested, threat),
    do: requested == threat or (String.ends_with?(threat, "/") and String.starts_with?(requested, threat))

  defp duration_seconds(value) when is_binary(value) do
    case Regex.run(~r/^(\d+)(?:\.\d{1,9})?s$/, value) do
      [_, number] -> String.to_integer(number)
      _ -> nil
    end
  end

  defp duration_seconds(_), do: nil

  defp check_result(url, status) do
    now = DateTime.utc_now() |> DateTime.to_iso8601()
    domain = Signals.parse(url).host |> Domain.registrable_domain()

    signals =
      if status == "matched" do
        [
          %{
            "id" => "google_safe_browsing",
            "severity" => "high",
            "message" =>
              "Google marca este enlace como posiblemente engañoso o peligroso. Puede haber errores u otras amenazas no detectadas.",
            "source" => @source,
            "domain" => domain,
            "checked_at" => now,
            "attribution" => "Advisory provided by Google",
            "source_url" => @advisory,
            "learn_more_url" => "https://www.antiphishing.org/"
          }
        ]
      else
        []
      end

    %{
      "url_hash" => hash(url),
      "domain" => domain,
      "status" => status,
      "checked_at" => now,
      "signals" => signals
    }
  end

  defp response(status, checks),
    do: %{status: status, checks: checks, signals: Enum.flat_map(checks, & &1["signals"])}

  defp hash(url), do: :crypto.hash(:sha256, url) |> Base.encode16(case: :lower)
  defp monotonic_now, do: System.monotonic_time(:millisecond)

  defp cache_get(hash, now) do
    if Process.whereis(__MODULE__), do: GenServer.call(__MODULE__, {:get, hash, now}), else: :miss
  end

  defp cache_put(values, now) do
    if Process.whereis(__MODULE__), do: GenServer.call(__MODULE__, {:put, values, now})
  end
end
