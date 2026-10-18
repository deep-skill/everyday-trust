defmodule EverydayTrust.AsyncSources do
  alias EverydayTrust.{Interpreter, SafeBrowsing, Urlscan}

  @rank %{"inconclusive" => 0, "no_signals_detected" => 0, "suspicious" => 1, "high_risk" => 2}

  def enrich(base, text, urls, options \\ []) do
    if Urlscan.enabled?() do
      interpretation =
        Task.async(fn -> protect(base, fn -> interpret(base, text, urls, options) end) end)

      navigation = Task.async(fn -> protect(base, fn -> Urlscan.enrich(base, urls) end) end)
      completed = Task.yield_many([interpretation, navigation], 31_000)

      values =
        Enum.map(completed, fn
          {_task, {:ok, result}} ->
            result

          {task, _} ->
            Task.shutdown(task, :brutal_kill)
            unavailable(base)
        end)

      [primary, scanned] = values
      merge(primary, scanned, base)
    else
      interpret(base, text, urls, options)
    end
  rescue
    _ -> unavailable(base)
  catch
    _, _ -> unavailable(base)
  end

  def merge(primary, scanned, base) do
    additional = Enum.reject(scanned["signals"], &(&1 in base["signals"]))
    higher = Map.fetch!(@rank, scanned["verdict"]) > Map.fetch!(@rank, primary["verdict"])

    score =
      min(100, primary["rules_score"] + max(0, scanned["rules_score"] - base["rules_score"]))

    primary =
      primary
      |> Map.update!("signals", &Enum.uniq_by(&1 ++ additional, fn item -> item["id"] end))
      |> Map.put("rules_score", score)
      |> put_in(["coverage", "urlscan"], scanned["coverage"]["urlscan"])
      |> Map.put("url_scans", Map.get(scanned, "url_scans", []))

    if higher,
      do: Map.merge(primary, Map.take(scanned, ["verdict", "summary", "risk_origin"])),
      else: primary
  end

  def unavailable(base) do
    Map.update!(base, "coverage", fn coverage ->
      Map.new(coverage, fn
        {key, "pending"} -> {key, "unavailable"}
        item -> item
      end)
    end)
  end

  defp interpret(base, text, urls, options) do
    checked = if SafeBrowsing.enabled?(), do: SafeBrowsing.enrich(base, urls), else: base

    if options[:skip_ai],
      do: put_in(checked, ["coverage", "ai"], "not_applicable"),
      else: Interpreter.enrich(checked, text)
  end

  defp protect(base, function) do
    function.()
  rescue
    _ -> unavailable(base)
  catch
    _, _ -> unavailable(base)
  end
end
