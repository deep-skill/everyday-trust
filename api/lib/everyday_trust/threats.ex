defmodule EverydayTrust.ThreatVersion do
  use Ecto.Schema
  @primary_key {:id, :binary_id, autogenerate: true}
  schema "threat_versions" do
    field :digest, :string
    field :fetched_at, :utc_datetime_usec
    field :published_at, :utc_datetime_usec
    field :active, :boolean, default: false
    field :record_count, :integer
  end
end

defmodule EverydayTrust.ThreatIndicator do
  use Ecto.Schema
  @primary_key false
  schema "threat_indicators" do
    field :version_id, :binary_id
    field :host, :string
    field :status, :string
  end
end

defmodule EverydayTrust.Threats do
  import Ecto.Query
  alias EverydayTrust.{Repo, ThreatVersion, ThreatIndicator, Signals, Domain}
  @source "https://github.com/Phishing-Database/Phishing.Database"
  @catalog_path Path.expand("../../priv/catalog/brands.json", __DIR__)
  @external_resource @catalog_path
  @official Jason.decode!(File.read!(@catalog_path))["brands"] |> Enum.flat_map(& &1["domains"])

  def enrich(findings) do
    version = Repo.one(from v in ThreatVersion, where: v.active)

    cond do
      findings == [] ->
        {findings, "not_applicable"}

      is_nil(version) ->
        {Enum.map(findings, &Map.put(&1, "feed_status", "unavailable")), "not_loaded"}

      DateTime.diff(DateTime.utc_now(), version.fetched_at) > 172_800 ||
          (version.published_at &&
             DateTime.diff(DateTime.utc_now(), version.published_at) > 2_592_000) ->
        {Enum.map(findings, &Map.put(&1, "feed_status", "unavailable")), "stale"}

      true ->
        historical =
          is_nil(version.published_at) ||
            DateTime.diff(DateTime.utc_now(), version.published_at) > 604_800

        hosts =
          Enum.flat_map(findings, &Map.get(&1, "checked_hosts", [&1["hostname"]]))
          |> Enum.reject(&is_nil/1)
          |> Enum.uniq()

        matched =
          Repo.all(
            from i in ThreatIndicator,
              where: i.version_id == ^version.id and i.host in ^hosts,
              select: {i.host, i.status}
          )
          |> Map.new()

        items =
          Enum.map(findings, fn finding ->
            statuses =
              Enum.map(Map.get(finding, "checked_hosts", [finding["hostname"]]), &matched[&1])

            status =
              cond do
                "active" in statuses -> "active"
                "needs_review" in statuses -> "needs_review"
                true -> nil
              end

            signal =
              case status do
                "active" ->
                  Signals.signal(
                    "reported_phishing",
                    if(historical, do: "medium", else: "high"),
                    if(historical,
                      do:
                        "El host figura en un reporte histórico de Phishing.Database; no confirma su estado actual.",
                      else:
                        "El host aparece reportado en Phishing.Database. Un reporte no identifica al remitente."
                    )
                  )

                "needs_review" ->
                  Signals.signal(
                    "source_conflict",
                    "medium",
                    "Hay un reporte que contradice el catálogo oficial. Esta comprobación necesita revisión; confirma por otro canal."
                  )

                _ ->
                  nil
              end

            signal =
              if signal,
                do:
                  Map.merge(signal, %{
                    "source" => @source,
                    "source_version" => version.digest,
                    "checked_at" => DateTime.to_iso8601(DateTime.utc_now()),
                    "source_published_at" =>
                      if(version.published_at, do: DateTime.to_iso8601(version.published_at))
                  })

            finding
            |> Map.put("signals", finding["signals"] ++ if(signal, do: [signal], else: []))
            |> Map.put(
              "feed_status",
              if(status == "active",
                do: "match",
                else: if(status == "needs_review", do: "unavailable", else: "no_match")
              )
            )
            |> Map.put("feed_version", version.digest)
            |> Map.put("feed_checked_at", DateTime.to_iso8601(version.fetched_at))
            |> Map.put(
              "feed_published_at",
              if(version.published_at, do: DateTime.to_iso8601(version.published_at))
            )
          end)

        {items,
         if(historical || Enum.any?(items, &(&1["feed_status"] == "unavailable")),
           do: "partial",
           else: "completed"
         )}
    end
  end

  def ingest(file, expected_digest, fetched_at, published_at, minimum \\ 1000) do
    with {:ok, %File.Stat{size: size}} when size > 0 and size <= 50_000_000 <- File.stat(file),
         {:ok, body} <- File.read(file),
         digest <- :crypto.hash(:sha256, body) |> Base.encode16(case: :lower),
         true <- digest == expected_digest,
         {:ok, date, _} <- DateTime.from_iso8601(fetched_at),
         age <- DateTime.diff(DateTime.utc_now(), date),
         true <- age >= -60 && age < 172_800,
         {:ok, published, _} <- DateTime.from_iso8601(published_at),
         publication_age <- DateTime.diff(DateTime.utc_now(), published),
         true <- publication_age >= -60 && publication_age < 2_592_000 do
      date = %{date | microsecond: {elem(date.microsecond, 0), 6}}
      published = %{published | microsecond: {elem(published.microsecond, 0), 6}}

      rows =
        String.split(body, ~r/\R/, trim: true)
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&String.starts_with?(&1, "#"))

      normalized = Enum.map(rows, &normalize/1) |> Enum.reject(&is_nil/1)
      hosts = Enum.uniq(normalized)

      if length(hosts) >= minimum && length(normalized) >= length(rows) * 0.99 do
        Repo.transaction(
          fn ->
            Repo.query!("SELECT pg_advisory_xact_lock(72310)")
            old = Repo.one(from v in ThreatVersion, where: v.active)

            if old && length(hosts) < old.record_count * 0.5,
              do: Repo.rollback(:unexpected_shrink)

            version =
              Repo.insert!(%ThreatVersion{
                digest: digest,
                fetched_at: date,
                published_at: published,
                record_count: length(hosts)
              })

            hosts
            |> Enum.map(fn host ->
              %{
                version_id: version.id,
                host: host,
                status:
                  if(
                    Enum.any?(@official, fn domain ->
                      host == domain || String.ends_with?(host, "." <> domain)
                    end),
                    do: "needs_review",
                    else: "active"
                  )
              }
            end)
            |> Enum.chunk_every(1000)
            |> Enum.each(&Repo.insert_all(ThreatIndicator, &1))

            Repo.update_all(from(v in ThreatVersion, where: v.active), set: [active: false])
            Repo.update!(Ecto.Changeset.change(version, active: true))

            %{
              version: version.id,
              digest: digest,
              records: length(hosts),
              fetched_at: date,
              published_at: published
            }
          end,
          timeout: 120_000
        )
      else
        {:error, :invalid_feed}
      end
    else
      _ -> {:error, :invalid_source}
    end
  end

  defp normalize(host) do
    if Regex.match?(~r/^[a-zA-Z0-9.-]{3,253}$/, host) do
      host = host |> String.trim_trailing(".") |> String.downcase()

      if (Signals.ip?(host) || Domain.matches_explicit_rule?(host)) &&
           Enum.all?(
             String.split(host, "."),
             &Regex.match?(~r/^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$/, &1)
           ),
         do: host
    end
  end
end
