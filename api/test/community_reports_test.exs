defmodule EverydayTrust.CommunityTest do
  use ExUnit.Case, async: false
  import Ecto.Query

  alias EverydayTrust.{
    Analysis,
    Case,
    Community,
    CommunityReport,
    Repo,
    ThreatIndicator,
    ThreatVersion
  }

  @network String.duplicate("f", 64)

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Repo, {:shared, self()})
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

  test "disabled features and missing consent never store a report" do
    item = item("bcp-acceso.example", session(1))

    assert {:error, 400, "consent_required"} =
             Community.submit(item.id, session(1), nil, @network, false)

    assert {:error, 400, "consent_required"} =
             Community.submit(item.id, session(1), nil, @network, "true")

    Application.put_env(:everyday_trust, :community_reports_enabled, false)
    assert {:error, 404, _} = Community.submit(item.id, session(1), nil, @network, true)
    assert {:error, 404, _} = Community.radar()
    assert Repo.aggregate(CommunityReport, :count) == 0
  end

  test "case ownership, completion, demos and official domains are enforced" do
    item = item("bcp-acceso.example", session(1))
    assert {:error, 404, _} = Community.submit(item.id, session(2), nil, @network, true)

    pending =
      Repo.update!(
        Ecto.Changeset.change(item,
          analysis_pending: true,
          analysis_deadline: DateTime.add(DateTime.utc_now(), 40)
        )
      )

    assert {:error, 409, _} = Community.submit(pending.id, session(1), nil, @network, true)
    Repo.update!(Ecto.Changeset.change(pending, analysis_pending: false, kind: "demo"))

    assert {:error, 400, "not_eligible"} =
             Community.submit(item.id, session(1), nil, @network, true)

    for domain <- [
          "viabcp.com",
          "sunat.gob.pe",
          "person.bad.example",
          "bad.example/private?secret=SECRET"
        ] do
      assert is_nil(Community.eligible_domain(result(domain)))
    end

    assert is_nil(
             Community.eligible_domain(
               Map.put(result("bcp-acceso.example"), "verdict", "inconclusive")
             )
           )
  end

  test "only five minimized fields are stored and session ids use a separate keyed pseudonym" do
    item = item("bcp-acceso.example", session(1))

    result =
      Map.merge(item.result, %{
        "original_message" => "SYNTHETICPERSON SECRET",
        "summary" => "PRIVATE_SUMMARY"
      })

    Repo.update!(Ecto.Changeset.change(item, result: result))
    assert {:ok, %{recorded: true}} = Community.submit(item.id, session(1), nil, @network, true)

    row = Repo.one!(CommunityReport)
    assert row.domain == "bcp-acceso.example"
    assert row.brand == "BCP"
    assert row.session_hash != session(1)
    assert String.match?(row.session_hash, ~r/^[a-f0-9]{64}$/)

    assert Enum.sort(CommunityReport.__schema__(:fields)) ==
             Enum.sort([:domain, :brand, :verdict, :reported_at, :session_hash])

    stored = inspect(Map.from_struct(row))
    refute stored =~ "SECRET"
    refute stored =~ "PRIVATE_SUMMARY"
    refute stored =~ "SYNTHETICPERSON"
    refute stored =~ item.id
    refute stored =~ @network
  end

  test "duplicate submissions are idempotent and cannot manufacture three distinct sessions" do
    item = item("bcp-acceso.example", session(1))

    for _ <- 1..5,
        do: assert({:ok, _} = Community.submit(item.id, session(1), nil, @network, true))

    assert Repo.aggregate(CommunityReport, :count) == 1
    assert Repo.aggregate(ThreatIndicator, :count) == 0

    for n <- 2..3 do
      next = item("bcp-acceso.example", session(n))
      assert {:ok, _} = Community.submit(next.id, session(n), nil, @network, true)
    end

    assert Repo.aggregate(CommunityReport, :count) == 3

    assert [%ThreatIndicator{host: "bcp-acceso.example", status: "candidate"}] =
             Repo.all(ThreatIndicator)
  end

  test "three sessions with independent evidence create a candidate without replacing the active feed" do
    now = DateTime.utc_now()

    active =
      Repo.insert!(%ThreatVersion{
        digest: String.duplicate("1", 64),
        fetched_at: now,
        published_at: now,
        active: true,
        record_count: 0
      })

    report_three("bcp-acceso.example")

    assert Repo.one!(from v in ThreatVersion, where: v.active).id == active.id
    community = Repo.one!(from v in ThreatVersion, where: not v.active)

    assert community.digest ==
             :crypto.hash(:sha256, "community-v1") |> Base.encode16(case: :lower)

    assert community.record_count == 1
    assert Repo.one!(ThreatIndicator).version_id == community.id
  end

  test "three reports without an independent signal remain reports only" do
    report_three("neutral.example")
    assert Repo.aggregate(CommunityReport, :count) == 3
    assert Repo.aggregate(ThreatIndicator, :count) == 0
    assert {:ok, %{new_domains: 0, brands: []}} = Community.radar()
  end

  test "Google evidence must be recent and bound to the reported domain" do
    signal = %{
      "id" => "google_safe_browsing",
      "domain" => "other.example",
      "checked_at" => timestamp(0)
    }

    report_three("neutral.example", %{"signals" => [signal]})
    assert Repo.aggregate(ThreatIndicator, :count) == 0

    old = %{signal | "domain" => "old.example", "checked_at" => timestamp(-90_000)}
    report_three("old.example", %{"signals" => [old]}, 10)
    assert Repo.aggregate(ThreatIndicator, :count) == 0

    current = %{signal | "domain" => "current.example"}
    report_three("current.example", %{"signals" => [current]}, 20)
    assert [%ThreatIndicator{host: "current.example"}] = Repo.all(ThreatIndicator)
  end

  test "urlscan corroboration cannot be borrowed from another domain" do
    scan = %{
      "status" => "matched",
      "domain" => "other.example",
      "hostname" => "other.example",
      "checked_at" => timestamp(0)
    }

    report_three("neutral.example", %{"url_scans" => [scan]})
    assert Repo.aggregate(ThreatIndicator, :count) == 0
    matched = %{scan | "domain" => "current.example", "hostname" => "login.current.example"}
    report_three("current.example", %{"url_scans" => [matched]}, 10)
    assert [%ThreatIndicator{host: "current.example"}] = Repo.all(ThreatIndicator)
  end

  test "an RDAP age signal is usable only when it names the case's single domain" do
    young = %{"id" => "new_domain", "checked_at" => timestamp(0)}

    findings = [
      %{"domain" => "young.example", "official_brand" => nil, "age_status" => "match"},
      %{"domain" => "second.example", "official_brand" => nil}
    ]

    report_three("young.example", %{"signals" => [young], "domains" => findings})
    assert Repo.aggregate(ThreatIndicator, :count) == 0

    report_three(
      "single.example",
      %{
        "signals" => [young],
        "domains" => [
          %{"domain" => "single.example", "age_status" => "match", "official_brand" => nil}
        ]
      },
      10
    )

    assert [%ThreatIndicator{host: "single.example"}] = Repo.all(ThreatIndicator)
  end

  test "community evidence is medium, never high, and never lowers an existing verdict" do
    report_three("bcp-acceso.example")

    base =
      result("bcp-acceso.example")
      |> Map.merge(%{"verdict" => "inconclusive", "signals" => [], "rules_score" => 0})

    enriched = Community.enrich(base)
    assert enriched["verdict"] == "suspicious"

    assert [%{"id" => "community_reported", "severity" => "medium", "source" => "comunidad"}] =
             enriched["signals"]

    assert enriched["community_domain"] == "bcp-acceso.example"
    assert Community.enrich(Map.put(base, "verdict", "high_risk"))["verdict"] == "high_risk"
  end

  test "public radar exposes aggregates only and uses first report time for the weekly window" do
    report_three("bcp-acceso.example")
    report_three("interbank-acceso.example", %{}, 10)
    {:ok, radar} = Community.radar()
    assert radar.new_domains == 2
    assert %{brand: "BCP", domains: 1} in radar.brands
    assert %{brand: "Interbank", domains: 1} in radar.brands
    refute Jason.encode!(radar) =~ ".example"

    Repo.update_all(from(r in CommunityReport, where: r.domain == "bcp-acceso.example"),
      set: [reported_at: DateTime.add(DateTime.utc_now(), -8 * 86_400)]
    )

    assert {:ok, %{new_domains: 1}} = Community.radar()
  end

  test "reports expire after thirty days and cannot keep a candidate eligible" do
    report_three("bcp-acceso.example")
    row = Repo.one!(from r in CommunityReport, limit: 1)

    Repo.update!(
      Ecto.Changeset.change(row, reported_at: DateTime.add(DateTime.utc_now(), -31 * 86_400))
    )

    refute Enum.any?(
             Community.enrich(result("bcp-acceso.example"))["signals"],
             &(&1["id"] == "community_reported")
           )

    assert :ok = Community.cleanup()
    assert Repo.aggregate(CommunityReport, :count) == 2
    assert Repo.aggregate(ThreatIndicator, :count) == 0
  end

  test "daily quotas reject new domains atomically while allowing an idempotent retry" do
    for n <- 1..3 do
      item = item("bcp-fixture#{n}.example", session(1))
      assert {:ok, _} = Community.submit(item.id, session(1), nil, @network, true)
    end

    fourth = item("bcp-fixture4.example", session(1))

    assert {:error, 429, "community_limit"} =
             Community.submit(fourth.id, session(1), nil, @network, true)

    assert Repo.aggregate(CommunityReport, :count) == 3

    first =
      Repo.one!(
        from c in Case,
          where: fragment("?->'domains'->0->>'domain'", c.result) == "bcp-fixture1.example"
      )

    assert {:ok, _} = Community.submit(first.id, session(1), nil, @network, true)
  end

  defp report_three(domain, overrides \\ %{}, offset \\ 0) do
    for n <- 1..3 do
      current = item(domain, session(n + offset), overrides)
      assert {:ok, _} = Community.submit(current.id, session(n + offset), nil, @network, true)
    end
  end

  defp item(domain, session, overrides \\ %{}) do
    now = DateTime.utc_now()
    current = Map.merge(result(domain), overrides)

    Repo.insert!(%Case{
      session_hash: session,
      result: current,
      context: Analysis.context(current),
      kind: "query",
      analysis_pending: false,
      expires_at: DateTime.add(now, 3_600),
      max_expires_at: DateTime.add(now, 14_400)
    })
  end

  defp result(domain),
    do: %{
      "analysis_status" => "completed",
      "verdict" => "suspicious",
      "summary" => "Caso sintético",
      "signals" => [],
      "rules_score" => 0,
      "scam_type" => "undetermined",
      "coverage" => %{},
      "domains" => [%{"domain" => domain, "official_brand" => nil}],
      "analyzed_at" => timestamp(0)
    }

  defp session(n),
    do: :crypto.hash(:sha256, "synthetic-session-#{n}") |> Base.encode16(case: :lower)

  defp timestamp(offset), do: DateTime.utc_now() |> DateTime.add(offset) |> DateTime.to_iso8601()
end
