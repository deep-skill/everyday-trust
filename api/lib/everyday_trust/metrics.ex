defmodule EverydayTrust.Metrics do
  alias EverydayTrust.{Repo, Cases}

  def increment(kind, metric) when kind in ["query", "demo", "site"] do
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

  def visit(session, network) do
    Repo.transaction(fn ->
      if Cases.quota(session, nil, "visit", 1) do
        unless Cases.quota(network, nil, "network_visits", 1000) &&
                 Cases.quota("global", nil, "all_visits", 5000),
               do: Repo.rollback(:quota)

        increment("site", "visits")
      end
    end)

    today()
  end

  def today do
    rows =
      Repo.query!("SELECT kind,metric,count FROM daily_metrics WHERE day=$1", [Date.utc_today()]).rows

    %{
      day: Date.utc_today(),
      timezone: "UTC",
      queries: counts(rows, "query"),
      demos: counts(rows, "demo"),
      totals: totals()
    }
  end

  defp totals do
    rows =
      Repo.query!("SELECT kind,metric,sum(count)::bigint FROM daily_metrics GROUP BY kind,metric").rows

    queries = counts(rows, "query")
    review_count = queries["review_count"] || 0

    %{
      visits: counts(rows, "site")["visits"] || 0,
      consultations: queries["completed"] || 0,
      reviews: review_count,
      rating: if(review_count > 0, do: Float.round(queries["rating_sum"] / review_count, 1))
    }
  end

  defp counts(rows, kind),
    do: rows |> Enum.filter(fn [k, _, _] -> k == kind end) |> Map.new(fn [_, m, n] -> {m, n} end)
end
