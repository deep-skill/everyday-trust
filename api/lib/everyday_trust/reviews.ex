defmodule EverydayTrust.Review do
  use Ecto.Schema
  @primary_key {:id, :binary_id, autogenerate: true}
  schema "reviews" do
    field :case_id, :binary_id
    field :owner_id, :binary_id
    field :kind, :string
    field :rating, :integer
    field :comment, :string
    timestamps(type: :utc_datetime_usec)
  end
end

defmodule EverydayTrust.Reviews do
  import Ecto.Query
  alias EverydayTrust.{Cases, Metrics, Repo, Review}

  def submit(id, session, owner, network, rating, comment)
      when is_integer(rating) and rating in 1..5 and is_binary(comment) do
    comment = String.trim(comment)

    cond do
      String.length(comment) > 500 ->
        {:error, 400, "invalid_review"}

      true ->
        with {:ok, item} <- Cases.get(id, session, owner) do
          if item.analysis_pending do
            {:error, 409, "analysis_in_progress"}
          else
            record(item, session, owner, network, rating, comment)
          end
        end
    end
  end

  def submit(_, _, _, _, _, _), do: {:error, 400, "invalid_review"}

  defp record(item, session, owner, network, rating, comment) do
    now = DateTime.utc_now()

    result =
      Repo.transaction(fn ->
        {count, _} =
          Repo.insert_all(
            Review,
            [
              %{
                id: Ecto.UUID.generate(),
                case_id: item.id,
                owner_id: if(owner, do: owner.id),
                kind: item.kind,
                rating: rating,
                comment: comment,
                inserted_at: now,
                updated_at: now
              }
            ],
            on_conflict: :nothing,
            conflict_target: :case_id
          )

        if count == 1 do
          unless Cases.quota(session, owner, "reviews", 3) &&
                   Cases.quota(network, nil, "network_reviews", 60) &&
                   Cases.quota("global", nil, "all_reviews", 500),
                 do: Repo.rollback(:quota)

          Metrics.increment(item.kind, "review_count")

          Repo.query!(
            "INSERT INTO daily_metrics(day,kind,metric,count) VALUES ($1,$2,'rating_sum',$3) ON CONFLICT(day,kind,metric) DO UPDATE SET count=daily_metrics.count+EXCLUDED.count",
            [Date.utc_today(), item.kind, rating]
          )
        end
      end)

    case result do
      {:ok, _} -> {:ok, %{recorded: true}}
      _ -> {:error, 429, "review_limit"}
    end
  end

  def delete(id, session, owner) do
    with {:ok, item} <- Cases.get(id, session, owner) do
      Repo.update_all(from(r in Review, where: r.case_id == ^item.id), set: [comment: ""])
      {:ok, %{deleted: true}}
    end
  end
end
