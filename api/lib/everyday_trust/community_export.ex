defmodule EverydayTrust.Community.Export do
  import Ecto.Query
  alias EverydayTrust.{Community, CommunityReport, Repo, ThreatIndicator, ThreatVersion}

  @digest :crypto.hash(:sha256, "community-v1") |> Base.encode16(case: :lower)
  @headers ~w(domain brand verdict first_reported_at last_reported_at distinct_sessions source)

  def csv do
    if Community.enabled?() do
      now = DateTime.utc_now()
      recent = DateTime.add(now, -7 * 86_400)
      retained = DateTime.add(now, -30 * 86_400)

      records = Repo.all(from r in CommunityReport,
        join: i in ThreatIndicator, on: i.host == r.domain and i.status == "candidate",
        join: v in ThreatVersion, on: v.id == i.version_id and v.digest == @digest,
        where: r.reported_at >= ^retained,
        group_by: r.domain,
        having: count(r.session_hash) >= 3 and max(r.reported_at) >= ^recent,
        order_by: r.domain,
        select: {
          r.domain, max(r.brand),
          fragment("CASE WHEN bool_or(? = 'high_risk') THEN 'high_risk' ELSE 'suspicious' END", r.verdict),
          min(r.reported_at), max(r.reported_at), count(r.session_hash)
        }
      )

      rows = Enum.map(records, fn {domain, brand, verdict, first, last, sessions} ->
        [domain, brand || "", verdict, DateTime.to_iso8601(first), DateTime.to_iso8601(last), to_string(sessions), "comunidad"]
      end)
      {:ok, Enum.map_join([@headers | rows], "\r\n", &line/1) <> "\r\n"}
    else
      {:error, :disabled}
    end
  end

  defp line(values), do: Enum.map_join(values, ",", &cell/1)

  defp cell(value) do
    safe =
      if Regex.match?(~r/\A(?:[\x00-\x20]*[=+\-@]|[\t\r\n])/u, value),
        do: "'" <> value,
        else: value

    "\"" <> String.replace(safe, "\"", "\"\"") <> "\""
  end
end
