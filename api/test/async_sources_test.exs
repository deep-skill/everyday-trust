defmodule EverydayTrust.AsyncSourcesTest do
  use ExUnit.Case, async: true
  alias EverydayTrust.{Analysis, AsyncSources}

  test "navigation evidence cannot erase a stronger primary verdict or other source data" do
    base = Analysis.run("Revisa este mensaje")
    primary = base
      |> Map.merge(%{"verdict" => "high_risk", "summary" => "Google advierte riesgo", "risk_origin" => "external_signal", "rules_score" => 45, "report_data" => %{"bank" => "synthetic"}, "scam_type" => "bank_impersonation"})
      |> Map.put("signals", [%{"id" => "google_safe_browsing", "severity" => "high"}])
      |> put_in(["coverage", "safe_browsing"], "completed")
      |> put_in(["coverage", "ai"], "completed")
    scanned = base
      |> Map.put("url_scans", [%{"status" => "no_match"}])
      |> put_in(["coverage", "urlscan"], "completed")

    merged = AsyncSources.merge(primary, scanned, base)
    assert merged["verdict"] == "high_risk"
    assert merged["summary"] == primary["summary"]
    assert merged["signals"] == primary["signals"]
    assert merged["scam_type"] == "bank_impersonation"
    assert merged["report_data"] == primary["report_data"]
    assert merged["domains"] == primary["domains"]
    assert merged["coverage"]["ai"] == "completed"
    assert merged["coverage"]["safe_browsing"] == "completed"
    assert merged["coverage"]["urlscan"] == "completed"
  end

  test "malicious navigation raises the verdict while retaining interpretation and all evidence" do
    base = Analysis.run("Revisa este mensaje")
    primary = base
      |> Map.merge(%{"verdict" => "suspicious", "scam_type" => "credential_theft"})
      |> put_in(["coverage", "ai"], "completed")
    signal = %{"id" => "urlscan_malicious", "severity" => "high"}
    scanned = base
      |> Map.merge(%{"verdict" => "high_risk", "summary" => "Indicios externos", "risk_origin" => "external_signal", "rules_score" => 45, "signals" => [signal]})
      |> put_in(["coverage", "urlscan"], "completed")

    merged = AsyncSources.merge(primary, scanned, base)
    assert merged["verdict"] == "high_risk"
    assert merged["scam_type"] == "credential_theft"
    assert merged["signals"] == [signal]
    assert merged["rules_score"] == 45
    assert merged["coverage"]["ai"] == "completed"
  end

  test "expired background work marks all pending sources unavailable" do
    base = Analysis.run("Revisa este mensaje")
      |> put_in(["coverage", "ai"], "pending")
      |> put_in(["coverage", "safe_browsing"], "pending")
      |> put_in(["coverage", "urlscan"], "pending")

    result = AsyncSources.unavailable(base)
    assert result["coverage"]["ai"] == "unavailable"
    assert result["coverage"]["safe_browsing"] == "unavailable"
    assert result["coverage"]["urlscan"] == "unavailable"
    assert result["coverage"]["official_domains"] == "completed"
    assert result["verdict"] == base["verdict"]
  end
end

defmodule EverydayTrust.AsyncSourcesSafetyTest do
  use ExUnit.Case, async: false
  alias EverydayTrust.{Analysis, AsyncSources}

  setup do
    keys = [:safe_browsing_enabled, :urlscan_enabled, :ai_provider, :ai_key, :ai_data_approved]
    original = Map.new(keys, &{&1, Application.fetch_env(:everyday_trust, &1)})

    on_exit(fn ->
      Enum.each(original, fn
        {key, {:ok, value}} -> Application.put_env(:everyday_trust, key, value)
        {key, :error} -> Application.delete_env(:everyday_trust, key)
      end)
    end)

    :ok
  end

  test "OCR cases omit the second model call while retaining the analysis" do
    Application.put_env(:everyday_trust, :safe_browsing_enabled, false)
    Application.put_env(:everyday_trust, :urlscan_enabled, false)
    Application.put_env(:everyday_trust, :ai_provider, "meta")
    Application.put_env(:everyday_trust, :ai_key, "synthetic-key")
    Application.put_env(:everyday_trust, :ai_data_approved, true)
    base = Analysis.run("Revisa este mensaje")
    result = AsyncSources.enrich(base, "Revisa este mensaje", [], skip_ai: true)
    assert result["coverage"]["ai"] == "not_applicable"
    assert result["signals"] == base["signals"]
    assert result["verdict"] == base["verdict"]
  end

  test "exceptions inside linked source tasks fall back without terminating the caller" do
    Application.put_env(:everyday_trust, :safe_browsing_enabled, true)
    Application.put_env(:everyday_trust, :urlscan_enabled, true)

    base =
      Analysis.run("Revisa este mensaje")
      |> put_in(["coverage", "ai"], "pending")
      |> put_in(["coverage", "safe_browsing"], "pending")
      |> put_in(["coverage", "urlscan"], "pending")

    result = AsyncSources.enrich(base, "Revisa este mensaje", nil)
    assert result["coverage"]["ai"] == "unavailable"
    assert result["coverage"]["safe_browsing"] == "unavailable"
    assert result["coverage"]["urlscan"] == "unavailable"
    assert result["verdict"] == base["verdict"]
  end
end
