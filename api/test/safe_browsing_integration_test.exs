defmodule EverydayTrust.SafeBrowsingIntegrationTest do
  use ExUnit.Case, async: false

  alias EverydayTrust.{Case, Cases, Repo, SafeBrowsing}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Repo, {:shared, self()})

    keys = [
      :safe_browsing_enabled,
      :safe_browsing_api_key,
      :test_safe_browsing_request,
      :ai_provider,
      :ai_data_approved
    ]

    original = Map.new(keys, &{&1, Application.fetch_env(:everyday_trust, &1)})
    Application.put_env(:everyday_trust, :safe_browsing_enabled, true)
    Application.put_env(:everyday_trust, :safe_browsing_api_key, "synthetic-test-key")
    Application.put_env(:everyday_trust, :ai_provider, "disabled")
    Application.put_env(:everyday_trust, :ai_data_approved, false)
    :sys.replace_state(SafeBrowsing, fn _ -> %{} end)

    on_exit(fn ->
      Enum.each(original, fn
        {key, {:ok, value}} -> Application.put_env(:everyday_trust, key, value)
        {key, :error} -> Application.delete_env(:everyday_trust, key)
      end)
    end)

    :ok
  end

  test "the initial response does not wait for Google and only structured evidence persists" do
    parent = self()

    Application.put_env(:everyday_trust, :test_safe_browsing_request, fn _, options ->
      send(parent, {:google_started, self(), options[:params]})

      receive do
        :finish -> :ok
      after
        1_000 -> :ok
      end

      {:ok,
       %{
         status: 200,
         body:
           Jason.encode!(%{
             "threats" => [
               %{"url" => "https://phishing.example/", "threatTypes" => ["SOCIAL_ENGINEERING"]}
             ],
             "cacheDuration" => "300s"
           })
       }}
    end)

    text = "SYNTHETICPERSON revisa https://phishing.example/PRIVATEPATH?token=SECRETQUERY"
    session = String.duplicate("c", 64)
    {:ok, initial} = Cases.create(text, session, nil)
    assert initial["analysis_status"] == "in_progress"
    assert initial["coverage"]["safe_browsing"] == "pending"
    assert initial["coverage"]["ai"] == "disabled"
    refute Enum.any?(initial["signals"], &(&1["id"] == "google_safe_browsing"))
    assert_receive {:google_started, pid, [{"urls", "https://phishing.example/PRIVATEPATH"}]}, 500
    send(pid, :finish)

    for _ <- 1..50 do
      if Repo.get!(Case, initial["id"]).analysis_pending, do: Process.sleep(10)
    end

    {:ok, finished} = Cases.get(initial["id"], session, nil)
    assert finished.result["analysis_status"] == "completed"
    assert finished.result["coverage"]["safe_browsing"] == "completed"
    assert finished.result["verdict"] == "high_risk"

    stored = Jason.encode!(%{result: finished.result, context: finished.context})
    refute stored =~ "SYNTHETICPERSON"
    refute stored =~ "PRIVATEPATH"
    refute stored =~ "SECRETQUERY"
  end
end
