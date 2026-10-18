defmodule EverydayTrust.Metrics do
  alias EverydayTrust.{Repo, Cases}

  def increment(kind, metric) when kind in ["query", "demo"] do
    Repo.query!(
      "INSERT INTO daily_metrics(day,kind,metric,count) VALUES ($1,$2,$3,1) ON CONFLICT(day,kind,metric) DO UPDATE SET count=daily_metrics.count+1",
      [Date.utc_today(), kind, metric]
    )
  end

  def complete(item) do
    increment(item.kind, "completed")
    subject = item.owner_id || item.session_hash
    unless Cases.quota(subject, nil, "completed", 1), do: increment(item.kind, "additional_case")
  end

  def feedback(kind, value), do: increment(kind, value)

  def error do
    increment("query", "request_error")
  rescue
    _ -> :ok
  end

  def today do
    rows =
      Repo.query!("SELECT kind,metric,count FROM daily_metrics WHERE day=$1", [Date.utc_today()]).rows

    %{
      day: Date.utc_today(),
      timezone: "UTC",
      queries: counts(rows, "query"),
      demos: counts(rows, "demo")
    }
  end

  defp counts(rows, kind),
    do: rows |> Enum.filter(fn [k, _, _] -> k == kind end) |> Map.new(fn [_, m, n] -> {m, n} end)
end
