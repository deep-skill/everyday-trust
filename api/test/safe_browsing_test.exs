defmodule EverydayTrust.SafeBrowsingTest do
  use ExUnit.Case, async: false

  alias EverydayTrust.{Analysis, SafeBrowsing}

  setup do
    keys = [:safe_browsing_enabled, :safe_browsing_api_key, :test_safe_browsing_request]
    original = Map.new(keys, &{&1, Application.fetch_env(:everyday_trust, &1)})
    Application.put_env(:everyday_trust, :safe_browsing_enabled, true)
    Application.put_env(:everyday_trust, :safe_browsing_api_key, "synthetic-test-key")

    if Process.whereis(SafeBrowsing),
      do: :sys.replace_state(SafeBrowsing, fn _ -> %{} end),
      else: start_supervised!(SafeBrowsing)

    on_exit(fn ->
      Enum.each(original, fn
        {key, {:ok, value}} -> Application.put_env(:everyday_trust, key, value)
        {key, :error} -> Application.delete_env(:everyday_trust, key)
      end)
    end)

    :ok
  end

  test "a current match yields a high signal with Google attribution and date" do
    stub(%{
      "threats" => [
        %{"url" => "https://phishing.example/", "threatTypes" => ["SOCIAL_ENGINEERING"]}
      ],
      "cacheDuration" => "300s"
    })

    checked = SafeBrowsing.check(["https://phishing.example/login"])

    assert checked.status == "completed"

    assert [
             %{
               "severity" => "high",
               "source" => "Google Safe Browsing",
               "checked_at" => date,
               "attribution" => "Advisory provided by Google"
             }
           ] = checked.signals

    assert {:ok, _, _} = DateTime.from_iso8601(date)
    assert [%{"status" => "matched"}] = checked.checks
  end

  test "no match stays neutral and cannot turn an inconclusive result green" do
    stub(%{"cacheDuration" => "300s"})
    original = Analysis.run("Revisa este mensaje", feed: false)
    result = SafeBrowsing.enrich(original, ["https://example.com/path"])
    assert result["verdict"] == original["verdict"]
    assert result["signals"] == original["signals"]
    assert result["coverage"]["safe_browsing"] == "completed"
  end

  test "a match never lowers an existing high risk verdict" do
    stub(%{
      "threats" => [%{"url" => "https://phishing.example/", "threatTypes" => ["MALWARE"]}],
      "cacheDuration" => "300s"
    })

    result =
      Analysis.run("Comparte tu clave y token ahora")
      |> SafeBrowsing.enrich(["https://phishing.example/"])

    assert result["verdict"] == "high_risk"
    assert Enum.any?(result["signals"], &(&1["id"] == "google_safe_browsing"))
  end

  test "global deadline returns unavailable without signals" do
    Application.put_env(:everyday_trust, :test_safe_browsing_request, fn _, _ ->
      Process.sleep(5_000)
      {:ok, %{status: 200, body: "{}"}}
    end)

    start = System.monotonic_time(:millisecond)

    assert %{status: "unavailable", signals: []} =
             SafeBrowsing.check(["https://timeout.example/"])

    assert System.monotonic_time(:millisecond) - start < 2_000
  end

  test "an available cached warning survives another URL timing out" do
    stub(%{
      "threats" => [
        %{"url" => "https://cached-danger.example/", "threatTypes" => ["SOCIAL_ENGINEERING"]}
      ],
      "cacheDuration" => "300s"
    })

    SafeBrowsing.check(["https://cached-danger.example/"])

    Application.put_env(:everyday_trust, :test_safe_browsing_request, fn _, _ ->
      Process.sleep(5_000)
      {:error, :timeout}
    end)

    checked = SafeBrowsing.check(["https://cached-danger.example/", "https://timeout.example/"])
    assert checked.status == "partial"
    assert [%{"id" => "google_safe_browsing"}] = checked.signals
  end

  test "missing key and disabled flag never contact the service" do
    Application.put_env(:everyday_trust, :test_safe_browsing_request, fn _, _ ->
      flunk("unexpected request")
    end)

    Application.delete_env(:everyday_trust, :safe_browsing_api_key)
    assert %{status: "unavailable", signals: []} = SafeBrowsing.check(["https://example.com/"])
    Application.put_env(:everyday_trust, :safe_browsing_enabled, false)
    assert %{status: "disabled", signals: []} = SafeBrowsing.check(["https://example.com/"])
  end

  test "only five sanitized URLs go to Google and the cache contains only hashes and minimized results" do
    parent = self()

    Application.put_env(:everyday_trust, :test_safe_browsing_request, fn endpoint, options ->
      send(parent, {:request, endpoint, options})
      {:ok, %{status: 200, body: Jason.encode!(%{"cacheDuration" => "3600s"})}}
    end)

    urls = for n <- 1..7, do: "https://USER:SECRET@sample#{n}.example/path?token=PRIVATE#VICTIM"
    checked = SafeBrowsing.check(urls)
    assert length(checked.checks) == 5
    assert_received {:request, "https://safebrowsing.googleapis.com/v5/urls:search", options}
    sent = options[:params] |> Enum.map(&elem(&1, 1))
    assert sent == for(n <- 1..5, do: "https://sample#{n}.example/path")
    refute inspect(options[:params]) =~ "PRIVATE"
    refute inspect(options[:params]) =~ "SECRET"
    refute inspect(checked) =~ "path"
    cache = :sys.get_state(SafeBrowsing)
    assert map_size(cache) == 5
    assert Enum.all?(Map.keys(cache), &String.match?(&1, ~r/^[0-9a-f]{64}$/))
    refute inspect(cache) =~ "https://sample"

    assert SafeBrowsing.check(urls).status == "completed"
    refute_received {:request, _, _}
  end

  test "expired cache entries are fetched again" do
    parent = self()

    Application.put_env(:everyday_trust, :test_safe_browsing_request, fn _, _ ->
      send(parent, :requested)
      {:ok, %{status: 200, body: Jason.encode!(%{"cacheDuration" => "300s"})}}
    end)

    SafeBrowsing.check(["https://cache.example/"])
    assert_received :requested

    :sys.replace_state(SafeBrowsing, fn state ->
      Map.new(state, fn {key, {_expires, value}} ->
        {key, {System.monotonic_time(:millisecond) - 1, value}}
      end)
    end)

    SafeBrowsing.check(["https://cache.example/"])
    assert_received :requested
  end

  test "positive cache is limited to thirty minutes even when the service returns longer" do
    stub(%{
      "threats" => [
        %{"url" => "https://cache.example/", "threatTypes" => ["SOCIAL_ENGINEERING"]}
      ],
      "cacheDuration" => "3600s"
    })

    SafeBrowsing.check(["https://cache.example/"])
    [{_hash, {expiry, _}}] = Map.to_list(:sys.get_state(SafeBrowsing))
    assert expiry - System.monotonic_time(:millisecond) <= 1_800_000
  end

  test "service failure and invalid JSON remain unavailable without green evidence" do
    for response <- [
          {:error, :timeout},
          {:ok, %{status: 429, body: "{}"}},
          {:ok, %{status: 200, body: "not-json"}},
          {:ok, %{status: 200, body: "{}"}},
          {:ok,
           %{
             status: 200,
             body: Jason.encode!(%{"cacheDuration" => "300s", "threats" => "invalid"})
           }}
        ] do
      Application.put_env(:everyday_trust, :test_safe_browsing_request, fn _, _ -> response end)

      assert %{status: "unavailable", signals: []} =
               SafeBrowsing.check(["https://error.example/"])
    end
  end

  test "domain suffix matching respects host boundaries" do
    stub(%{
      "threats" => [
        %{"url" => "https://danger.example/", "threatTypes" => ["SOCIAL_ENGINEERING"]}
      ],
      "cacheDuration" => "300s"
    })

    checked = SafeBrowsing.check(["https://sub.danger.example/", "https://notdanger.example/"])
    assert Enum.map(checked.checks, & &1["status"]) == ["matched", "no_match"]
  end

  test "a path match does not taint a different path with the same initial characters" do
    stub(%{
      "threats" => [
        %{"url" => "https://danger.example/login", "threatTypes" => ["SOCIAL_ENGINEERING"]}
      ],
      "cacheDuration" => "300s"
    })

    checked =
      SafeBrowsing.check(["https://danger.example/login", "https://danger.example/login-help"])

    assert Enum.map(checked.checks, & &1["status"]) == ["matched", "no_match"]
  end

  defp stub(body) do
    Application.put_env(:everyday_trust, :test_safe_browsing_request, fn _, _ ->
      {:ok, %{status: 200, body: Jason.encode!(body)}}
    end)
  end
end
