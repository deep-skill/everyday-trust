defmodule EverydayTrust.UrlscanIntegrationTest do
  use ExUnit.Case, async: false

  alias EverydayTrust.{Case, Cases, Repo, SafeBrowsing}
  alias EverydayTrust.Urlscan.Cache

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Repo, {:shared, self()})

    keys = [
      :urlscan_enabled,
      :urlscan_api_key,
      :test_urlscan_request,
      :test_urlscan_wait,
      :test_urlscan_quota,
      :safe_browsing_enabled,
      :safe_browsing_api_key,
      :test_safe_browsing_request,
      :ai_provider,
      :ai_data_approved
    ]

    original = Map.new(keys, &{&1, Application.fetch_env(:everyday_trust, &1)})
    Application.put_env(:everyday_trust, :urlscan_enabled, true)
    Application.put_env(:everyday_trust, :urlscan_api_key, "synthetic-test-key")
    Application.put_env(:everyday_trust, :safe_browsing_enabled, true)
    Application.put_env(:everyday_trust, :safe_browsing_api_key, "synthetic-test-key")
    Application.put_env(:everyday_trust, :ai_provider, "disabled")
    Application.put_env(:everyday_trust, :ai_data_approved, false)
    Application.put_env(:everyday_trust, :test_urlscan_quota, fn -> true end)
    :sys.replace_state(Cache, fn _ -> %{entries: %{}, pending: %{}} end)
    :sys.replace_state(SafeBrowsing, fn _ -> %{} end)

    on_exit(fn ->
      Enum.each(original, fn
        {key, {:ok, value}} -> Application.put_env(:everyday_trust, key, value)
        {key, :error} -> Application.delete_env(:everyday_trust, key)
      end)
    end)

    :ok
  end

  test "rules return before scanning and the final merge retains both external sources without the message" do
    parent = self()
    uuid = "99d0b58c-6058-4d49-8eae-0e42d6c48fbd"

    Application.put_env(:everyday_trust, :test_safe_browsing_request, fn _, _ ->
      send(parent, :google_completed)

      {:ok,
       %{
         status: 200,
         body:
           Jason.encode!(%{
             "cacheDuration" => "300s",
             "threats" => [
               %{"url" => "https://unlisted.example/", "threatTypes" => ["SOCIAL_ENGINEERING"]}
             ]
           })
       }}
    end)

    Application.put_env(:everyday_trust, :test_urlscan_wait, fn _ ->
      send(parent, {:scan_waiting, self()})

      receive do
        :finish -> :ok
      after
        1_000 -> :ok
      end
    end)

    Application.put_env(:everyday_trust, :test_urlscan_request, fn options ->
      body =
        if options[:method] == :post do
          %{"uuid" => uuid, "visibility" => "unlisted"}
        else
          %{
            "task" => %{"visibility" => "unlisted", "time" => "2026-10-18T13:00:00Z"},
            "page" => %{"url" => "https://landing.example/", "title" => "Página sintética"},
            "verdicts" => %{"urlscan" => %{"malicious" => true, "brands" => []}}
          }
        end

      {:ok, %{status: 200, body: Jason.encode!(body)}}
    end)

    text = "SYNTHETICPERSON revisa https://unlisted.example/PRIVATEPATH?token=SECRETQUERY"
    session = String.duplicate("d", 64)
    {:ok, initial} = Cases.create(text, session, nil)
    assert initial["analysis_status"] == "in_progress"
    assert initial["coverage"]["urlscan"] == "pending"
    assert_receive :google_completed, 500
    assert_receive {:scan_waiting, scanner}, 500
    assert Repo.get!(Case, initial["id"]).analysis_pending
    send(scanner, :finish)

    for _ <- 1..100 do
      if Repo.get!(Case, initial["id"]).analysis_pending, do: Process.sleep(10)
    end

    {:ok, finished} = Cases.get(initial["id"], session, nil)
    assert finished.result["analysis_status"] == "completed"
    assert finished.result["revision"] == 2
    assert finished.result["coverage"]["urlscan"] == "completed"
    assert finished.result["coverage"]["safe_browsing"] == "completed"
    assert finished.result["verdict"] == "high_risk"
    assert Enum.any?(finished.result["signals"], &(&1["id"] == "urlscan_malicious"))
    assert Enum.any?(finished.result["signals"], &(&1["id"] == "google_safe_browsing"))
    stored = Jason.encode!(%{result: finished.result, context: finished.context})
    refute stored =~ "SYNTHETICPERSON"
    refute stored =~ "PRIVATEPATH"
    refute stored =~ "SECRETQUERY"
  end
end
