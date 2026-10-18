defmodule EverydayTrust.Community.ExportTest do
  use ExUnit.Case, async: false
  alias EverydayTrust.{CommunityReport, Repo, ThreatIndicator, ThreatVersion}
  alias EverydayTrust.Community.Export

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    previous = Application.fetch_env(:everyday_trust, :community_reports_enabled)
    Application.put_env(:everyday_trust, :community_reports_enabled, true)
    on_exit(fn ->
      case previous do
        {:ok, value} -> Application.put_env(:everyday_trust, :community_reports_enabled, value)
        :error -> Application.delete_env(:everyday_trust, :community_reports_enabled)
      end
    end)
    :ok
  end

  test "only current community candidates with three distinct sessions are exported" do
    candidate("bcp-fixture.example", "BCP", 3, 0)
    candidate("two.example", nil, 2, 0)
    candidate("old.example", nil, 3, -8 * 86_400)
    candidate("other-source.example", nil, 3, 0, String.duplicate("f", 64))

    assert {:ok, csv} = Export.csv()
    assert csv =~ "bcp-fixture.example"
    assert csv =~ "\"high_risk\""
    assert csv =~ "\"3\",\"comunidad\""
    refute csv =~ "two.example"
    refute csv =~ "old.example"
    refute csv =~ "other-source.example"
    refute csv =~ "session_hash"
    refute csv =~ String.duplicate("a", 64)
    assert length(String.split(csv, "\r\n", trim: true)) == 2
  end

  test "CSV cells escape quotes and neutralize spreadsheet formulas and leading whitespace" do
    for {brand, n} <- Enum.with_index(["=1+1", "+SUM(1,1)", "-2+3", "@SUM(A1)", "  =1+1", "\t=1+1", "Banco \"Demo\""], 1) do
      candidate("fixture#{n}.example", brand, 3, 0)
    end

    assert {:ok, csv} = Export.csv()
    for formula <- ["=1+1", "+SUM(1,1)", "-2+3", "@SUM(A1)", "  =1+1", "\t=1+1"], do: assert(csv =~ "\"'#{formula}\"")
    assert csv =~ "\"Banco \"\"Demo\"\"\""
  end

  test "disabled exports return no data and an empty week yields a header only" do
    assert {:ok, header} = Export.csv()
    assert length(String.split(header, "\r\n", trim: true)) == 1
    Application.put_env(:everyday_trust, :community_reports_enabled, false)
    assert {:error, :disabled} = Export.csv()
  end

  defp candidate(domain, brand, sessions, offset, digest \\ nil) do
    now = DateTime.utc_now()
    digest = digest || (:crypto.hash(:sha256, "community-v1") |> Base.encode16(case: :lower))
    version = Repo.get_by(ThreatVersion, digest: digest) || Repo.insert!(%ThreatVersion{digest: digest, active: false, fetched_at: now, published_at: now, record_count: 0})
    Repo.insert_all(ThreatIndicator, [%{version_id: version.id, host: domain, status: "candidate"}])
    for n <- 1..sessions do
      Repo.insert!(%CommunityReport{domain: domain, brand: brand, verdict: if(n == 1, do: "high_risk", else: "suspicious"), session_hash: String.pad_leading(to_string(n), 64, "a"), reported_at: DateTime.add(now, offset)})
    end
  end
end
