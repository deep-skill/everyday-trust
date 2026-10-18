defmodule EverydayTrust.Analysis do
  alias EverydayTrust.Signals
  @weights %{"high" => 45, "medium" => 15, "low" => 5, "info" => 0}
  @summary %{
    "high_risk" => "Hay varias señales de riesgo. Haz una pausa y verifica antes de actuar.",
    "suspicious" => "Hay señales sospechosas que conviene comprobar por otro canal.",
    "no_signals_detected" =>
      "Los dominios revisados coinciden con sitios oficiales y no detectamos otras señales. Esto no autentica al remitente.",
    "inconclusive" =>
      "No contamos con señales suficientes para decidir. La ausencia de señales no garantiza seguridad."
  }
  @actions [
    "No compartas claves ni códigos por mensaje.",
    "Verifica desde la app de tu banco o un contacto que ya conozcas."
  ]

  def run(text, options \\ []) do
    network = Application.get_env(:everyday_trust, :network_checks, true)
    urls = Signals.extract_urls(text)
    local_findings = Enum.map(urls, &Signals.url(&1, false))

    findings =
      urls
      |> Enum.with_index()
      |> Task.async_stream(
        fn {url, i} ->
          if(network && i < 5, do: Signals.url(url, true), else: Enum.at(local_findings, i))
        end,
        max_concurrency: 5,
        timeout: 4_000,
        on_timeout: :kill_task,
        ordered: true
      )
      |> Enum.zip(local_findings)
      |> Enum.map(fn
        {{:ok, result}, _local} ->
          result

        {_, local} ->
          Map.merge(local, %{
            "age_status" => "unavailable",
            "redirect_status" => "unavailable"
          })
      end)

    {findings, feed_status} =
      if options[:feed],
        do: EverydayTrust.Threats.enrich(findings),
        else: {findings, "not_integrated"}

    signals =
      Signals.text(text) ++ Signals.phones(text) ++ Enum.flat_map(findings, & &1["signals"])

    signals =
      if length(urls) > 5,
        do:
          signals ++
            [
              Signals.signal(
                "incomplete_link_checks",
                "medium",
                "La comprobación externa está limitada a cinco enlaces."
              )
            ],
        else: signals

    score = min(100, Enum.reduce(signals, 0, fn s, n -> n + @weights[s["severity"]] end))
    official = findings != [] && Enum.all?(findings, &is_binary(&1["official_brand"]))

    verdict =
      cond do
        score >= 60 ->
          "high_risk"

        score >= 15 ->
          "suspicious"

        score == 0 && official && (!options[:feed] || feed_status == "completed") ->
          "no_signals_detected"

        true ->
          "inconclusive"
      end

    now = DateTime.utc_now() |> DateTime.to_iso8601()

    evidence =
      Enum.map(
        signals,
        &(&1 |> Map.put_new("source", "rules-2026-10-17") |> Map.put_new("checked_at", now))
      )

    %{
      "schema_version" => 1,
      "policy_version" => "2026-10-17.1",
      "revision" => 1,
      "analysis_status" => "completed",
      "analysis_mode" => "signals",
      "verdict" => verdict,
      "baseline_verdict" => verdict,
      "risk_origin" => "rules",
      "rules_score" => score,
      "scam_type" => "undetermined",
      "summary" => @summary[verdict],
      "signals" => evidence,
      "domains" =>
        Enum.map(
          findings,
          &Map.take(&1, [
            "domain",
            "official_brand",
            "age_status",
            "redirect_status",
            "feed_status",
            "feed_version",
            "feed_checked_at",
            "feed_published_at"
          ])
        ),
      "coverage" => %{
        "official_domains" => "completed",
        "registration" =>
          if(Enum.any?(findings, &(&1["age_status"] == "unavailable")),
            do: "partial",
            else: "completed"
          ),
        "threat_feed" => feed_status,
        "ai" => "disabled"
      },
      "advice" => advice(signals),
      "analyzed_at" => now
    }
  end

  def minimize(text) do
    text
    |> String.replace(~r/https?:\/\/\S+|(?:[\p{L}\p{N}-]+\.)+[a-z]{2,}[^\s]*/iu, "[ENLACE]")
    |> String.replace(~r/[^\s@]+@[^\s@]+/u, "[CORREO]")
    |> String.replace(~r/(?:\+?\d[\d\s-]{1,}\d)/u, "[DATO NUMERICO]")
    |> String.replace(
      ~r/(?:clave|contrase[ñn]a|token|cvv|pin|c[oó]digo)\s*[:=]\s*\S+/iu,
      "[SECRETO OMITIDO]"
    )
    |> String.slice(0, 3_000)
  end

  def context(result),
    do: Jason.encode!(Map.take(result, ["verdict", "signals", "domains", "scam_type"]))

  defp advice(signals) do
    ids = Enum.map(signals, & &1["id"])

    cond do
      "extortion" in ids ->
        [
          "Busca ayuda por un canal oficial si existe una amenaza inmediata.",
          "Conserva las pruebas sin reenviarlas aquí. No envíes dinero ni nuevos datos por presión."
        ]

      "family_impersonation" in ids ->
        [
          "Llama a tu familiar al número que ya tenías guardado.",
          "Confirma quién escribe antes de enviar dinero. No uses un contacto nuevo enviado en ese mensaje."
        ]

      "asks_credentials" in ids ->
        [
          "No ingreses claves ni códigos en el enlace recibido.",
          "Abre la app de tu banco por tu cuenta y revisa allí los avisos y canales de ayuda."
        ]

      "package_held" in ids ->
        [
          "Revisa el pedido desde la web o app que ya utilizas.",
          "Busca tú mismo el contacto del servicio de entrega antes de pagar o compartir datos."
        ]

      "brand_lookalike" in ids || "reported_phishing" in ids ->
        [
          "No abras el enlace recibido.",
          "Busca la web oficial por tu cuenta o consulta desde la app que ya utilizas."
        ]

      true ->
        @actions
    end
  end
end
