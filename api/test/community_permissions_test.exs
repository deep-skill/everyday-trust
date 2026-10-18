defmodule EverydayTrust.CommunityPermissionsTest do
  use ExUnit.Case, async: false

  alias EverydayTrust.{CommunityReport, Repo, ThreatIndicator, ThreatVersion}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    :ok
  end

  test "a restricted runtime role can add only inactive community candidates through the functions" do
    now = DateTime.utc_now()
    active = Repo.insert!(%ThreatVersion{digest: String.duplicate("2", 64), fetched_at: now, published_at: now, active: true, record_count: 0})

    rows = for n <- 1..3 do
      %{domain: "bcp-fixture.example", session_hash: String.pad_leading("#{n}", 64, "0"), brand: "BCP", verdict: "suspicious", reported_at: now}
    end
    Repo.insert_all(CommunityReport, rows)

    role = "community_runtime_test_#{System.unique_integer([:positive])}"
    Repo.query!("CREATE ROLE #{role} NOLOGIN")
    Repo.query!("GRANT USAGE ON SCHEMA public TO #{role}")
    Repo.query!("GRANT SELECT ON public.threat_versions, public.threat_indicators TO #{role}")
    Repo.query!("GRANT EXECUTE ON FUNCTION public.promote_community_candidate(text), public.cleanup_community_candidates() TO #{role}")
    Repo.query!("SET LOCAL ROLE #{role}")

    try do
      assert Repo.query!("SELECT has_table_privilege(current_user, 'public.threat_versions', 'UPDATE'), has_table_privilege(current_user, 'public.threat_indicators', 'INSERT')").rows == [[false, false]]
      assert Repo.query!("SELECT public.promote_community_candidate($1)", ["bcp-fixture.example"]).rows == [[true]]
      assert Repo.query!("SELECT public.promote_community_candidate($1)", ["unreported.example"]).rows == [[false]]
      assert Repo.query!("SELECT public.promote_community_candidate($1)", ["invalid.example/path"]).rows == [[false]]
      assert Repo.query!("SELECT public.cleanup_community_candidates()").rows == [[0]]
    after
      Repo.query!("RESET ROLE")
    end

    assert Repo.get!(ThreatVersion, active.id).active
    assert [%ThreatIndicator{status: "candidate", host: "bcp-fixture.example", version_id: version_id}] = Repo.all(ThreatIndicator)
    version = Repo.get!(ThreatVersion, version_id)
    refute version.active
    assert version.digest == (:crypto.hash(:sha256, "community-v1") |> Base.encode16(case: :lower))
  end

  test "the definer functions do not grant execution to PUBLIC and pin their search path" do
    result = Repo.query!("""
    SELECT p.prosecdef, p.proconfig,
           NOT EXISTS (SELECT 1 FROM pg_catalog.aclexplode(p.proacl) AS privilege
                       WHERE privilege.grantee = 0 AND privilege.privilege_type = 'EXECUTE')
      FROM pg_catalog.pg_proc AS p
      JOIN pg_catalog.pg_namespace AS n ON n.oid = p.pronamespace
      WHERE n.nspname = 'public'
        AND p.proname IN ('promote_community_candidate', 'cleanup_community_candidates')
    """)

    assert length(result.rows) == 2
    for [definer, config, no_public] <- result.rows do
      assert definer
      assert "search_path=pg_catalog, pg_temp" in config
      assert no_public
    end
  end
end
