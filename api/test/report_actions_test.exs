defmodule EverydayTrust.ReportActionsTest do
  use ExUnit.Case, async: false
  alias EverydayTrust.ReportActions

  setup do
    previous = Application.get_env(:everyday_trust, :report_actions_enabled)
    Application.delete_env(:everyday_trust, :report_actions_enabled)

    on_exit(fn ->
      if is_nil(previous),
        do: Application.delete_env(:everyday_trust, :report_actions_enabled),
        else: Application.put_env(:everyday_trust, :report_actions_enabled, previous)
    end)

    :ok
  end

  test "report actions are disabled by default" do
    assert ReportActions.actions(result("bcp-acceso.example")) == []
  end

  test "report URLs and text contain only a root domain, reviewed date and curated brand" do
    Application.put_env(:everyday_trust, :report_actions_enabled, true)

    input =
      result("bcp-acceso.example")
      |> Map.put("original_message", "victim@private.example SECRET")
      |> Map.put("summary", "SECRET")

    [action] = ReportActions.actions(input)
    assert action["brand"] == "BCP"
    assert action["date"] == "2026-10-18"

    assert action["text"] ==
             "Posible sitio sospechoso: bcp-acceso.example\nFecha de revisión (UTC): 2026-10-18\nPosible marca imitada: BCP"

    google = Enum.find(action["channels"], &(&1["id"] == "google-phishing-report"))
    assert URI.parse(google["public_value"]).host == "safebrowsing.google.com"

    assert URI.decode_query(URI.parse(google["public_value"]).query) == %{
             "url" => "https://bcp-acceso.example/"
           }

    refute Jason.encode!(action) =~ "SECRET"
    refute Jason.encode!(action) =~ "victim@"
    assert Enum.any?(action["channels"], &(&1["id"] == "bcp-report-guidance"))
    refute Enum.any?(action["channels"], &(&1["id"] == "interbank-report-guidance"))
  end

  test "official sites and non suspicious verdicts cannot be offered for reporting" do
    Application.put_env(:everyday_trust, :report_actions_enabled, true)

    for domain <- ["viabcp.com", "interbank.pe", "sunat.gob.pe"] do
      assert ReportActions.actions(result(domain)) == []
    end

    for verdict <- ["inconclusive", "no_signals_detected"] do
      assert ReportActions.actions(Map.put(result("bcp-acceso.example"), "verdict", verdict)) ==
               []
    end
  end

  test "unrecognized brands retain only common official reporting channels" do
    Application.put_env(:everyday_trust, :report_actions_enabled, true)
    [action] = ReportActions.actions(result("unknown.example"))
    assert is_nil(action["brand"])
    assert length(action["channels"]) == 2
    assert Enum.all?(action["channels"], &is_nil(&1["brand"]))

    [bank] = ReportActions.actions(result("bbva-acceso.example"))
    assert bank["brand"] == "BBVA"
    assert length(bank["channels"]) == 2
  end

  test "paths, query strings, subdomains, IPs and injected markup are not report domains" do
    Application.put_env(:everyday_trust, :report_actions_enabled, true)

    for invalid <- [
          "bad.example/person?token=SECRET#fragment",
          "https://bad.example",
          "person.bad.example",
          "192.0.2.1",
          "<script>alert(1)</script>",
          nil
        ] do
      assert ReportActions.actions(result(invalid)) == []
    end
  end

  test "report channels have verified provenance and never use unreviewed email addresses" do
    Application.put_env(:everyday_trust, :report_actions_enabled, true)
    [action] = ReportActions.actions(result("interbank-acceso.example"))
    assert action["brand"] == "Interbank"
    assert Enum.any?(action["channels"], &(&1["id"] == "interbank-report-guidance"))

    for channel <- action["channels"] do
      assert channel["purpose"] == "reporte"
      assert channel["status"] == "active"
      assert channel["verified_at"] == "2026-10-18"
      assert String.starts_with?(channel["source"], "https://")
      assert String.starts_with?(channel["public_value"], "https://")
    end
  end

  defp result(domain) do
    %{
      "verdict" => "suspicious",
      "analyzed_at" => "2026-10-18T08:10:00Z",
      "domains" => [%{"domain" => domain, "official_brand" => nil}]
    }
  end
end
