defmodule EverydayTrust.CommunityReport do
  use Ecto.Schema
  @primary_key false

  schema "community_reports" do
    field :domain, :string, primary_key: true
    field :session_hash, :string, primary_key: true
    field :brand, :string
    field :verdict, :string
    field :reported_at, :utc_datetime_usec
  end
end

defmodule EverydayTrust.Community do
  import Ecto.Query
  alias EverydayTrust.{Cases, CommunityReport, Domain, Repo, Signals, ThreatIndicator, ThreatVersion}

  @catalog_path Path.expand("../../priv/catalog/brands.json", __DIR__)
  @external_resource @catalog_path
  @brands Jason.decode!(File.read!(@catalog_path))["brands"]
  @digest :crypto.hash(:sha256, "community-v1") |> Base.encode16(case: :lower)
  @domain ~r/\A(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\z/

  def enabled?, do: Application.get_env(:everyday_trust, :community_reports_enabled, false) == true

  def eligible_domain(result) do
    if enabled?() and result["analysis_status"] == "completed" and result["verdict"] in ["suspicious", "high_risk"] do
      result
      |> Map.get("domains", [])
      |> Enum.find_value(fn finding ->
        domain = finding["domain"]
        if valid_domain?(domain) and is_nil(finding["official_brand"]), do: domain
      end)
    end
  end

  def submit(id, session, owner, network, consent) do
    cond do
      not enabled?() -> {:error, 404, "feature_disabled"}
      consent != true -> {:error, 400, "consent_required"}
      not is_binary(session) or byte_size(session) == 0 -> {:error, 400, "invalid_session"}
      true ->
        with {:ok, item} <- Cases.get(id, session, owner) do
          cond do
            item.analysis_pending -> {:error, 409, "analysis_in_progress"}
            item.kind == "demo" -> {:error, 400, "not_eligible"}
            is_nil(eligible_domain(item.result)) -> {:error, 400, "not_eligible"}
            true -> record(item.result, session, network)
          end
        end
    end
  end

  def enrich(result) do
    if enabled?() do
      domains = result |> Map.get("domains", []) |> Enum.map(& &1["domain"]) |> Enum.filter(&valid_domain?/1) |> Enum.uniq()
      matched = candidates(domains)
      now = DateTime.utc_now() |> DateTime.to_iso8601()
      signals = for domain <- matched do
        %{
          "id" => "community_reported",
          "severity" => "medium",
          "message" => "Este dominio fue reportado por varias sesiones de la comunidad y requiere revisión. Los reportes no prueban por sí solos una estafa.",
          "source" => "comunidad",
          "domain" => domain,
          "checked_at" => now
        }
      end

      result =
        result
        |> Map.update!("signals", &Enum.uniq_by(&1 ++ signals, fn signal -> {signal["id"], signal["domain"]} end))
        |> put_in(["coverage", "community"], "completed")

      result =
        if signals != [] and result["verdict"] in ["inconclusive", "no_signals_detected"] do
          result
          |> Map.put("verdict", "suspicious")
          |> Map.put("summary", "Hay reportes de la comunidad sobre este dominio. Confirma por un canal oficial antes de actuar.")
          |> Map.put("risk_origin", "external_signal")
          |> Map.update!("rules_score", &min(100, &1 + 15))
        else
          result
        end

      Map.put(result, "community_domain", eligible_domain(result))
    else
      result
    end
  rescue
    _ -> result |> put_in(["coverage", "community"], "unavailable") |> Map.put("community_domain", nil)
  end

  def radar do
    if enabled?() do
      now = DateTime.utc_now()
      from = DateTime.add(now, -7 * 86_400)
      cutoff = DateTime.add(now, -30 * 86_400)

      rows = Repo.all(from r in CommunityReport,
        join: i in ThreatIndicator, on: i.host == r.domain and i.status == "candidate",
        join: v in ThreatVersion, on: v.id == i.version_id and v.digest == @digest,
        where: r.reported_at >= ^cutoff,
        group_by: r.domain,
        having: count(r.session_hash) >= 3 and min(r.reported_at) >= ^from,
        select: {r.domain, max(r.brand)}
      )

      brands = rows
        |> Enum.frequencies_by(fn {_, brand} -> brand || "Sin marca identificada" end)
        |> Enum.map(fn {brand, count} -> %{brand: brand, domains: count} end)
        |> Enum.sort_by(fn item -> {-item.domains, item.brand} end)
        |> Enum.take(10)

      {:ok, %{new_domains: length(rows), brands: brands, from: DateTime.to_iso8601(from), to: DateTime.to_iso8601(now)}}
    else
      {:error, 404, "feature_disabled"}
    end
  end

  def cleanup do
    cutoff = DateTime.add(DateTime.utc_now(), -30 * 86_400)
    Repo.delete_all(from r in CommunityReport, where: r.reported_at < ^cutoff)
    recent = from r in CommunityReport, where: r.reported_at >= ^cutoff, group_by: r.domain, having: count(r.session_hash) >= 3, select: r.domain
    versions = from v in ThreatVersion, where: v.digest == @digest, select: v.id
    Repo.delete_all(from i in ThreatIndicator, where: i.version_id in subquery(versions) and i.host not in subquery(recent))
    :ok
  end

  defp record(result, session, network) do
    domain = eligible_domain(result)
    secret = Application.fetch_env!(:everyday_trust, :service_token)
    pseudonym = :crypto.mac(:hmac, :sha256, secret, "community-v1:" <> session) |> Base.encode16(case: :lower)
    now = DateTime.utc_now()

    outcome = Repo.transaction(fn ->
      Repo.query!("SELECT pg_advisory_xact_lock(72311)")
      cleanup()
      {count, _} = Repo.insert_all(CommunityReport, [%{
        domain: domain,
        session_hash: pseudonym,
        brand: brand(domain),
        verdict: result["verdict"],
        reported_at: now
      }], on_conflict: :nothing, conflict_target: [:domain, :session_hash])

      if count == 1 do
        unless Cases.quota(session, nil, "community", 3) and
                 Cases.quota(network, nil, "network_community", 60) and
                 Cases.quota("global", nil, "all_community", 500),
               do: Repo.rollback(:quota)

        reports = Repo.aggregate(from(r in CommunityReport, where: r.domain == ^domain), :count)
        if reports >= 3 and independent?(domain, result), do: promote(domain, now)
      end

      %{recorded: true}
    end)

    case outcome do
      {:ok, response} -> {:ok, response}
      {:error, _} -> {:error, 429, "community_limit"}
    end
  end

  defp independent?(domain, result) do
    local = Signals.url("https://" <> domain, false)
    lookalike = Enum.any?(local["signals"], &(&1["id"] == "brand_lookalike"))
    signals = Map.get(result, "signals", [])
    google = Enum.any?(signals, &(&1["id"] == "google_safe_browsing" and &1["domain"] == domain and fresh?(&1["checked_at"])))
    single = case result["domains"] do
      [%{"domain" => ^domain, "age_status" => "match"}] -> true
      _ -> false
    end
    young = single and Enum.any?(signals, &(&1["id"] == "new_domain" and fresh?(&1["checked_at"])))
    scanned = Enum.any?(Map.get(result, "url_scans", []), fn scan ->
      scan["status"] == "matched" and scan["domain"] == domain and
        is_binary(scan["hostname"]) and Domain.registrable_domain(scan["hostname"]) == domain and fresh?(scan["checked_at"])
    end)
    lookalike or google or young or scanned
  end

  defp fresh?(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, time, _} -> DateTime.diff(DateTime.utc_now(), time) in -60..86_400
      _ -> false
    end
  end

  defp fresh?(_), do: false

  defp promote(domain, now) do
    version = Repo.one(from v in ThreatVersion, where: v.digest == @digest)
    version = version || Repo.insert!(%ThreatVersion{digest: @digest, active: false, record_count: 0, fetched_at: now, published_at: now})
    Repo.insert_all(ThreatIndicator, [%{version_id: version.id, host: domain, status: "candidate"}], on_conflict: :nothing, conflict_target: [:version_id, :host])
    count = Repo.aggregate(from(i in ThreatIndicator, where: i.version_id == ^version.id), :count)
    Repo.update!(Ecto.Changeset.change(version, record_count: count, fetched_at: now))
  end

  defp candidates([]), do: []
  defp candidates(domains) do
    cutoff = DateTime.add(DateTime.utc_now(), -30 * 86_400)
    Repo.all(from i in ThreatIndicator,
      join: v in ThreatVersion, on: v.id == i.version_id and v.digest == @digest,
      join: r in CommunityReport, on: r.domain == i.host,
      where: i.host in ^domains and i.status == "candidate" and r.reported_at >= ^cutoff,
      group_by: i.host,
      having: count(r.session_hash) >= 3,
      select: i.host
    )
  end

  defp valid_domain?(domain) when is_binary(domain) do
    byte_size(domain) <= 253 and Regex.match?(@domain, domain) and
      not Signals.ip?(domain) and Domain.registrable_domain(domain) == domain and
      is_nil(Signals.url("https://" <> domain, false)["official_brand"])
  end
  defp valid_domain?(_), do: false

  defp brand(domain) do
    checks = Signals.url("https://" <> domain, false)
    Enum.find_value(@brands, fn entry ->
      name = entry["name"]
      if Enum.any?(checks["signals"], &(&1["id"] == "brand_lookalike" and &1["message"] == "El enlace menciona a #{name}, pero no pertenece a su dominio oficial.")), do: name
    end)
  end
end
