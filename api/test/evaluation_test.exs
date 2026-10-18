defmodule EverydayTrust.EvaluationTest do
  use ExUnit.Case, async: false
  @fixtures Jason.decode!(File.read!(Path.expand("fixtures/evaluation.json", __DIR__)))

  test "synthetic corpus reports abstentions separately from dangerous green verdicts" do
    previous = Application.get_env(:everyday_trust, :network_checks)
    Application.put_env(:everyday_trust, :network_checks, false)
    on_exit(fn -> Application.put_env(:everyday_trust, :network_checks, previous) end)

    rows =
      Enum.map(@fixtures, fn fixture ->
        result = EverydayTrust.Analysis.run(fixture["text"])
        Map.take(fixture, ["id", "label"]) |> Map.put("verdict", result["verdict"])
      end)

    dangerous =
      Enum.count(rows, &(&1["label"] == "risky" && &1["verdict"] == "no_signals_detected"))

    false_alarms =
      Enum.count(
        rows,
        &(&1["label"] == "legitimate" && &1["verdict"] in ["high_risk", "suspicious"])
      )

    report = %{
      mode: "rules_offline_synthetic",
      cases: length(rows),
      dangerous_green: dangerous,
      false_alarms: false_alarms,
      abstentions: Enum.count(rows, &(&1["verdict"] == "inconclusive")),
      rows: rows
    }

    IO.puts("EVALUATION_REPORT:" <> Jason.encode!(report))
    assert dangerous == 0
    assert false_alarms == 0
  end
end
