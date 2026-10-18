defmodule EverydayTrust.UrlscanTest do
  use ExUnit.Case, async: false

  alias EverydayTrust.{Analysis, Cases, Repo, Urlscan}
  alias EverydayTrust.Urlscan.Cache

  @uuid "99d0b58c-6058-4d49-8eae-0e42d6c48fbd"

  setup do
    keys = [:urlscan_enabled, :urlscan_api_key, :test_urlscan_request, :test_urlscan_wait, :test_urlscan_quota, :test_urlscan_deadline]
    original = Map.new(keys, &{&1, Application.fetch_env(:everyday_trust, &1)})
    Application.put_env(:everyday_trust, :urlscan_enabled, true)
    Application.put_env(:everyday_trust, :urlscan_api_key, "synthetic-test-key")
    Application.put_env(:everyday_trust, :test_urlscan_wait, fn _ -> :ok end)
    Application.put_env(:everyday_trust, :test_urlscan_quota, fn -> true end)

    if Process.whereis(Cache),
      do: :sys.replace_state(Cache, fn _ -> %{entries: %{}, pending: %{}} end),
      else: start_supervised!(Cache)

    on_exit(fn ->
      Enum.each(original, fn
        {key, {:ok, value}} -> Application.put_env(:everyday_trust, key, value)
        {key, :error} -> Application.delete_env(:everyday_trust, key)
      end)
    end)

    :ok
  end

  test "malicious scans add dated external evidence with a trusted report link" do
    stub(true)
    original = Analysis.run("Necesito revisar un enlace")
    enriched = Urlscan.enrich(original, ["https://danger.example/signin?recipient=PRIVATE#FRAGMENT"])

    assert enriched["verdict"] == "high_risk"
    assert enriched["coverage"]["urlscan"] == "completed"
    assert [%{"id" => "urlscan_malicious", "severity" => "high", "checked_at" => date}] = enriched["signals"]
    assert {:ok, _, _} = DateTime.from_iso8601(date)
    assert [%{"status" => "matched", "report_url" => report, "final_hostname" => "landing.example", "brands" => ["Banco sintético"]}] = enriched["url_scans"]
    assert report == "https://urlscan.io/result/#{@uuid}/"
    refute Jason.encode!(enriched) =~ "PRIVATE"
    refute Jason.encode!(enriched) =~ "FRAGMENT"
  end

  test "a clean scan stays neutral and never authenticates the sender" do
    stub(false)
    original = Analysis.run("Un mensaje para revisar")
    enriched = Urlscan.enrich(original, ["https://clean.example/"])

    assert enriched["verdict"] == original["verdict"]
    assert enriched["signals"] == original["signals"]
    assert [%{"status" => "no_match"}] = enriched["url_scans"]
  end

  test "pending scans expire without evidence and honor polling cadence" do
    parent = self()
    Application.put_env(:everyday_trust, :test_urlscan_wait, fn milliseconds -> send(parent, {:wait, milliseconds}) end)
    Application.put_env(:everyday_trust, :test_urlscan_request, fn options ->
      if options[:method] == :post,
        do: submission(),
        else: {:ok, %{status: 404, body: "{}"}}
    end)

    assert %{"status" => "timeout"} = Urlscan.check("https://pending.example/")
    assert_received {:wait, 10_000}
    assert_received {:wait, 5_000}
    assert_received {:wait, 5_000}
    assert_received {:wait, 5_000}
    refute_received {:wait, _}
  end

  test "service errors, deletion and malformed responses remain unavailable" do
    for response <- [
          {:error, :timeout},
          {:ok, %{status: 429, body: "{}"}},
          {:ok, %{status: 410, body: "{}"}},
          {:ok, %{status: 200, body: "invalid"}},
          {:ok, %{status: 200, body: "{}"}}
        ] do
      :sys.replace_state(Cache, fn _ -> %{entries: %{}, pending: %{}} end)
      Application.put_env(:everyday_trust, :test_urlscan_request, fn options ->
        if options[:method] == :post, do: submission(), else: response
      end)

      assert %{"status" => "unavailable"} = Urlscan.check("https://error.example/")
    end
  end

  test "an unresponsive scan is killed by its total deadline and releases capacity" do
    Application.put_env(:everyday_trust, :test_urlscan_deadline, 30)
    Application.put_env(:everyday_trust, :test_urlscan_request, fn _ ->
      Process.sleep(5_000)
      submission()
    end)

    started = System.monotonic_time(:millisecond)
    assert %{"status" => "timeout"} = Urlscan.check("https://unresponsive.example/")
    assert System.monotonic_time(:millisecond) - started < 500
    assert :sys.get_state(Cache).pending == %{}
  end

  test "only sanitized URLs and an explicit unlisted visibility are submitted" do
    parent = self()
    stub(false, fn options -> send(parent, {:request, options}) end)
    checked = Urlscan.check("https://USER:SECRET@clean.example/customer?token=PRIVATE#FRAGMENT")

    assert checked["status"] == "no_match"
    assert_received {:request, options}
    assert options[:json] == %{"url" => "https://clean.example/customer", "visibility" => "unlisted"}
    assert options[:redirect] == false
    assert options[:retry] == false
    assert_received {:request, result_options}
    assert result_options[:url] == "https://urlscan.io/api/v1/result/#{@uuid}/"
    refute Jason.encode!(checked) =~ "customer"
    refute inspect(:sys.get_state(Cache)) =~ "SECRET"
    refute inspect(:sys.get_state(Cache)) =~ "PRIVATE"
  end

  test "public visibility and arbitrary report URLs from the provider are never accepted" do
    Application.put_env(:everyday_trust, :test_urlscan_request, fn _ ->
      {:ok, %{status: 200, body: Jason.encode!(%{"uuid" => @uuid, "visibility" => "public", "result" => "https://evil.example/"})}}
    end)

    assert %{"status" => "unavailable"} = Urlscan.check("https://visibility.example/")
  end

  test "result visibility is checked again before exposing metadata" do
    Application.put_env(:everyday_trust, :test_urlscan_request, fn options ->
      if options[:method] == :post do
        submission()
      else
        response = put_in(scan_result(false), ["task", "visibility"], "public")
        {:ok, %{status: 200, body: Jason.encode!(response)}}
      end
    end)

    assert %{"status" => "unavailable"} = Urlscan.check("https://visibility.example/")
  end

  test "disabled flags and missing keys never call urlscan" do
    Application.put_env(:everyday_trust, :test_urlscan_request, fn _ -> flunk("unexpected request") end)
    Application.delete_env(:everyday_trust, :urlscan_api_key)
    assert %{"status" => "unavailable"} = Urlscan.check("https://clean.example/")
    Application.put_env(:everyday_trust, :urlscan_enabled, false)
    assert %{"status" => "disabled"} = Urlscan.check("https://clean.example/")
  end

  test "quota exhaustion prevents submissions" do
    Application.put_env(:everyday_trust, :test_urlscan_quota, fn -> false end)
    Application.put_env(:everyday_trust, :test_urlscan_request, fn _ -> flunk("unexpected request") end)
    assert %{"status" => "budget_exhausted"} = Urlscan.check("https://quota.example/")
  end

  test "the shared persistent quota cannot be exceeded by concurrent reservations" do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Repo, {:shared, self()})
    subject = "synthetic-urlscan-#{System.unique_integer([:positive])}"

    for _ <- 1..299, do: assert(Cases.quota(subject, nil, "urlscan", 300))

    reservations =
      1..5
      |> Task.async_stream(fn _ -> Cases.quota(subject, nil, "urlscan", 300) end)
      |> Enum.map(fn {:ok, allowed} -> allowed end)

    assert Enum.count(reservations, & &1) == 1
    refute Cases.quota(subject, nil, "urlscan", 300)
  end

  test "successful domain snapshots are cached for six hours without mixing subdomains" do
    parent = self()
    stub(false, fn options -> if options[:method] == :post, do: send(parent, :submitted) end)
    Urlscan.check("https://cache.example/one")
    assert_received :submitted
    assert Urlscan.check("https://cache.example/two")["cached"]
    refute_received :submitted
    Urlscan.check("https://different.cache.example/")
    assert_received :submitted

    state = :sys.get_state(Cache)
    assert map_size(state.entries) == 2
    {expires, cached} = state.entries["cache.example"]
    assert expires - System.monotonic_time(:millisecond) <= 21_600_000
    assert expires - System.monotonic_time(:millisecond) > 21_590_000
    refute Jason.encode!(cached) =~ "/one"
    :sys.replace_state(Cache, fn current -> put_in(current, [:entries, "cache.example"], {System.monotonic_time(:millisecond) - 1, cached}) end)
    Urlscan.check("https://cache.example/three")
    assert_received :submitted
  end

  test "cache reservations allow at most three active scans and collapse the same host" do
    assert {:reserved, token} = Cache.reserve("one.example")
    assert :busy = Cache.reserve("one.example")
    assert {:reserved, _} = Cache.reserve("two.example")
    assert {:reserved, _} = Cache.reserve("three.example")
    assert :busy = Cache.reserve("four.example")
    :ok = Cache.complete("one.example", token, %{"status" => "no_match"})
    assert {:reserved, _} = Cache.reserve("four.example")
    assert {:cached, %{"status" => "no_match"}} = Cache.reserve("one.example")
  end

  test "private hosts, nonstandard ports and unsupported schemes are rejected" do
    for url <- ["http://localhost", "https://app.internal/", "http://127.0.0.1/", "http://169.254.169.254/", "https://[::1]/", "https://example.com:8443/", "ftp://example.com/file"] do
      assert is_nil(Urlscan.sanitize_url(url))
    end
  end

  test "external titles and brand lists are bounded text, never instructions or HTML" do
    body = scan_result(false)
    body = put_in(body, ["page", "title"], String.duplicate("<script>untrusted</script>", 100))
    body = put_in(body, ["verdicts", "urlscan", "brands"], for(_ <- 1..20, do: %{"name" => String.duplicate("x", 200)}))

    Application.put_env(:everyday_trust, :test_urlscan_request, fn options ->
      if options[:method] == :post, do: submission(), else: {:ok, %{status: 200, body: Jason.encode!(body)}}
    end)

    checked = Urlscan.check("https://bounded.example/")
    assert String.length(checked["page_title"]) == 160
    assert length(checked["brands"]) == 5
    assert Enum.all?(checked["brands"], &(String.length(&1) == 80))
  end

  defp stub(malicious, observer \\ fn _ -> :ok end) do
    Application.put_env(:everyday_trust, :test_urlscan_request, fn options ->
      observer.(options)
      if options[:method] == :post, do: submission(), else: {:ok, %{status: 200, body: Jason.encode!(scan_result(malicious))}}
    end)
  end

  defp submission,
    do: {:ok, %{status: 200, body: Jason.encode!(%{"uuid" => @uuid, "visibility" => "unlisted"})}}

  defp scan_result(malicious),
    do: %{
      "task" => %{"visibility" => "unlisted", "time" => "2026-10-18T13:00:00Z"},
      "page" => %{"url" => "https://landing.example/private?victim=SECRET#FRAGMENT", "title" => "Página sintética"},
      "verdicts" => %{"urlscan" => %{"malicious" => malicious, "brands" => [%{"name" => "Banco sintético"}]}}
    }
end
