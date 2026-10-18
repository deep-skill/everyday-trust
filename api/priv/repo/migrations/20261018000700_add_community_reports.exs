defmodule EverydayTrust.Repo.Migrations.AddCommunityReports do
  use Ecto.Migration

  def change do
    create table(:community_reports, primary_key: false) do
      add :domain, :text, primary_key: true
      add :session_hash, :text, primary_key: true
      add :brand, :text
      add :verdict, :text, null: false
      add :reported_at, :utc_datetime_usec, null: false
    end

    create index(:community_reports, [:reported_at])

    create constraint(:community_reports, :community_session_hash_length,
             check: "char_length(session_hash) = 64"
           )

    create constraint(:community_reports, :community_domain_length,
             check: "char_length(domain) BETWEEN 3 AND 253"
           )

    create constraint(:community_reports, :community_verdict,
             check: "verdict IN ('suspicious', 'high_risk')"
           )

    execute(
      """
      CREATE FUNCTION public.promote_community_candidate(candidate_domain text)
      RETURNS boolean
      LANGUAGE plpgsql
      SECURITY DEFINER
      SET search_path = pg_catalog, pg_temp
      AS $function$
      DECLARE
        target_version uuid;
        current_time_utc timestamp := pg_catalog.timezone('UTC', pg_catalog.statement_timestamp());
        community_digest constant text := '7f7b4d58efc656920e09f1cb7d17a655744c0c59de8dca4e96e8958255412abd';
      BEGIN
        IF candidate_domain IS NULL OR pg_catalog.length(candidate_domain) NOT BETWEEN 3 AND 253
           OR candidate_domain !~ '^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)+$' THEN
          RETURN false;
        END IF;

        PERFORM pg_catalog.pg_advisory_xact_lock(72311);

        IF (SELECT pg_catalog.count(*) FROM public.community_reports
            WHERE domain = candidate_domain AND reported_at >= current_time_utc - interval '30 days') < 3 THEN
          RETURN false;
        END IF;

        IF EXISTS (SELECT 1 FROM public.threat_versions WHERE digest = community_digest AND active) THEN
          RAISE EXCEPTION 'The community version must remain inactive';
        END IF;

        SELECT id INTO target_version FROM public.threat_versions
          WHERE digest = community_digest AND NOT active;

        IF target_version IS NULL THEN
          target_version := pg_catalog.gen_random_uuid();
          INSERT INTO public.threat_versions (id, digest, fetched_at, published_at, active, record_count)
            VALUES (target_version, community_digest, current_time_utc, current_time_utc, false, 0);
        END IF;

        INSERT INTO public.threat_indicators (version_id, host, status)
          VALUES (target_version, candidate_domain, 'candidate')
          ON CONFLICT (version_id, host) DO NOTHING;

        UPDATE public.threat_versions SET
          record_count = (SELECT pg_catalog.count(*) FROM public.threat_indicators WHERE version_id = target_version),
          fetched_at = current_time_utc
          WHERE id = target_version AND digest = community_digest AND NOT active;

        RETURN true;
      END;
      $function$
      """,
      "DROP FUNCTION public.promote_community_candidate(text)"
    )

    execute(
      "REVOKE ALL ON FUNCTION public.promote_community_candidate(text) FROM PUBLIC",
      "SELECT 1"
    )

    execute(
      """
      CREATE FUNCTION public.cleanup_community_candidates()
      RETURNS integer
      LANGUAGE plpgsql
      SECURITY DEFINER
      SET search_path = pg_catalog, pg_temp
      AS $function$
      DECLARE
        removed integer;
        community_digest constant text := '7f7b4d58efc656920e09f1cb7d17a655744c0c59de8dca4e96e8958255412abd';
      BEGIN
        PERFORM pg_catalog.pg_advisory_xact_lock(72311);

        DELETE FROM public.threat_indicators AS indicator
          USING public.threat_versions AS version
          WHERE indicator.version_id = version.id
            AND version.digest = community_digest AND NOT version.active
            AND indicator.status = 'candidate'
            AND (SELECT pg_catalog.count(*) FROM public.community_reports AS report
                 WHERE report.domain = indicator.host
                   AND report.reported_at >= pg_catalog.timezone('UTC', pg_catalog.statement_timestamp()) - interval '30 days') < 3;

        GET DIAGNOSTICS removed = ROW_COUNT;

        UPDATE public.threat_versions AS version SET
          record_count = (SELECT pg_catalog.count(*) FROM public.threat_indicators WHERE version_id = version.id)
          WHERE version.digest = community_digest AND NOT version.active;

        RETURN removed;
      END;
      $function$
      """,
      "DROP FUNCTION public.cleanup_community_candidates()"
    )

    execute(
      "REVOKE ALL ON FUNCTION public.cleanup_community_candidates() FROM PUBLIC",
      "SELECT 1"
    )
  end
end
