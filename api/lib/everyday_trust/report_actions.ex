defmodule EverydayTrust.ReportActions do
  alias EverydayTrust.{Domain, Signals}

  @catalog_path Path.expand("../../priv/catalog/official_channels.json", __DIR__)
  @external_resource @catalog_path
  @channels Jason.decode!(File.read!(@catalog_path))["channels"]
  @brands_path Path.expand("../../priv/catalog/brands.json", __DIR__)
  @external_resource @brands_path
  @brands Jason.decode!(File.read!(@brands_path))["brands"]
  @domain ~r/\A(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\z/

  def enabled?, do: Application.get_env(:everyday_trust, :report_actions_enabled, false)

  def enrich(result), do: Map.put(result, "report_actions", actions(result))

  def actions(result) do
    if enabled?() && result["verdict"] in ["suspicious", "high_risk"] do
      result
      |> Map.get("domains", [])
      |> Enum.flat_map(fn finding ->
        case candidate(finding) do
          {domain, checks} -> [action(domain, checks, result["analyzed_at"])]
          nil -> []
        end
      end)
      |> Enum.uniq_by(& &1["domain"])
      |> Enum.take(5)
    else
      []
    end
  end

  defp candidate(%{"domain" => domain} = finding) when is_binary(domain) do
    if byte_size(domain) <= 253 && Regex.match?(@domain, domain) &&
         Domain.registrable_domain(domain) == domain && !Signals.ip?(domain) &&
         is_nil(finding["official_brand"]) do
      checks = Signals.url("https://" <> domain, false)
      if is_nil(checks["official_brand"]), do: {domain, checks}
    end
  end

  defp candidate(_), do: nil

  defp action(domain, checks, timestamp) do
    brand = imitated_brand(checks)
    date = report_date(timestamp)

    channels =
      @channels
      |> Enum.filter(fn channel ->
        channel["purpose"] == "reporte" && channel["status"] == "active" &&
          (is_nil(channel["brand"]) || channel["brand"] == brand)
      end)
      |> Enum.map(fn
        %{"id" => "google-phishing-report"} = channel ->
          Map.update!(channel, "public_value", fn base ->
            base <> "?" <> URI.encode_query(%{"url" => "https://" <> domain <> "/"})
          end)

        channel ->
          channel
      end)

    text =
      "Posible sitio sospechoso: #{domain}\nFecha de revisión (UTC): #{date}" <>
        if(brand, do: "\nPosible marca imitada: #{brand}", else: "")

    %{
      "domain" => domain,
      "brand" => brand,
      "date" => date,
      "text" => text,
      "channels" => channels
    }
  end

  defp imitated_brand(checks) do
    Enum.find_value(@brands, fn entry ->
      brand = entry["name"]

      if is_binary(brand) &&
           Enum.any?(checks["signals"], fn signal ->
             signal["id"] == "brand_lookalike" &&
               signal["message"] ==
                 "El enlace menciona a #{brand}, pero no pertenece a su dominio oficial."
           end),
         do: brand
    end)
  end

  defp report_date(timestamp) when is_binary(timestamp) do
    case DateTime.from_iso8601(timestamp) do
      {:ok, date, _} -> date |> DateTime.to_date() |> Date.to_iso8601()
      _ -> Date.utc_today() |> Date.to_iso8601()
    end
  end

  defp report_date(_), do: Date.utc_today() |> Date.to_iso8601()
end
