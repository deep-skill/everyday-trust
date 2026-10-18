defmodule EverydayTrust.ThreatsTest do
  use ExUnit.Case, async: false
  import Ecto.Query
  alias EverydayTrust.{Repo, Threats, ThreatVersion, Analysis}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Repo, {:shared, self()})
    file = Path.join(System.tmp_dir!(), "trust-feed-#{System.unique_integer([:positive])}.txt")
    on_exit(fn -> File.rm(file) end)
    %{feed_file: file}
  end

  defp load(file, hosts) do
    body = Enum.join(hosts, "\n")
    File.write!(file, body)
    sha = :crypto.hash(:sha256, body) |> Base.encode16(case: :lower)

    Threats.ingest(
      file,
      sha,
      DateTime.to_iso8601(DateTime.utc_now()),
      DateTime.to_iso8601(DateTime.utc_now()),
      1
    )
  end

  test "snapshot publication, exact-host matches and provenance", %{feed_file: file} do
    assert {:ok, snapshot} = load(file, ["reported.example.com"])
    result = Analysis.run("https://reported.example.com/private?person=OMITTED", feed: true)
    signal = Enum.find(result["signals"], &(&1["id"] == "reported_phishing"))
    assert signal["source_version"] == snapshot.digest
    assert result["coverage"]["threat_feed"] == "completed"
    refute String.contains?(Jason.encode!(result), "OMITTED")

    refute Enum.any?(
             Analysis.run("https://other.example.com", feed: true)["signals"],
             &(&1["id"] == "reported_phishing")
           )
  end

  test "a failed import leaves active snapshot untouched", %{feed_file: file} do
    {:ok, first} = load(file, ["reported.example.com"])
    File.write!(file, "")

    assert {:error, _} =
             Threats.ingest(
               file,
               "bad",
               DateTime.to_iso8601(DateTime.utc_now()),
               DateTime.to_iso8601(DateTime.utc_now()),
               1
             )

    assert Repo.one(from v in ThreatVersion, where: v.active).id == first.version
  end

  test "an alert on an intermediate checked host is retained", %{feed_file: file} do
    {:ok, _} = load(file, ["reported.example.com"])

    finding = %{
      "hostname" => "final.example.com",
      "checked_hosts" => ["first.example.com", "reported.example.com", "final.example.com"],
      "signals" => []
    }

    assert {[result], "completed"} = Threats.enrich([finding])
    assert result["feed_status"] == "match"
    assert Enum.any?(result["signals"], &(&1["id"] == "reported_phishing"))
  end

  test "expired or absent feed does not produce a green result", %{feed_file: file} do
    assert Analysis.run("https://www.viabcp.com", feed: true)["verdict"] == "inconclusive"
    {:ok, _} = load(file, ["reported.example.com"])
    assert Analysis.run("https://www.viabcp.com", feed: true)["verdict"] == "no_signals_detected"
    Repo.update_all(ThreatVersion, set: [fetched_at: DateTime.add(DateTime.utc_now(), -200_000)])
    result = Analysis.run("https://www.viabcp.com", feed: true)
    assert result["verdict"] == "inconclusive"
    assert result["coverage"]["threat_feed"] == "stale"
  end

  test "catalog conflicts require review and cannot silently authorize a link", %{feed_file: file} do
    assert {:ok, _} = load(file, ["www.viabcp.com"])
    result = Analysis.run("https://www.viabcp.com", feed: true)
    assert result["verdict"] == "suspicious"
    assert result["coverage"]["threat_feed"] == "partial"
    assert Enum.any?(result["signals"], &(&1["id"] == "source_conflict"))
  end

  test "fetching an old publication never makes it current", %{feed_file: file} do
    {:ok, _} = load(file, ["reported.example.com"])

    Repo.update_all(ThreatVersion,
      set: [published_at: DateTime.add(DateTime.utc_now(), -1_300_000)]
    )

    result = Analysis.run("https://reported.example.com", feed: true)
    assert result["coverage"]["threat_feed"] == "partial"

    assert Enum.find(result["signals"], &(&1["id"] == "reported_phishing"))["severity"] ==
             "medium"

    assert Analysis.run("https://www.viabcp.com", feed: true)["verdict"] == "inconclusive"
  end
end
