defmodule EverydayTrust.TractionTest do
  use ExUnit.Case, async: false
  alias EverydayTrust.{Cases, Metrics, Repo, Review, Reviews}
  @session String.duplicate("a", 64)
  @other String.duplicate("b", 64)

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Repo, {:shared, self()})
    :ok
  end

  test "visits deduplicate concurrent requests without counting them as consultations" do
    1..10
    |> Task.async_stream(fn _ -> Metrics.visit(@session, @other) end, max_concurrency: 5)
    |> Stream.run()

    assert Metrics.today().totals.visits == 1
    assert Metrics.today().totals.consultations == 0
    assert Metrics.visit(@other, @other).totals.visits == 2
  end

  test "ratings exclude demonstrations and duplicate submissions" do
    {:ok, demo} = Cases.create("Hola", @session, nil, demo: true)
    {:ok, real} = Cases.create("Un mensaje sintético", @session, nil)
    assert {:ok, _} = Reviews.submit(demo["id"], @session, nil, @other, 1, "Demo")
    assert {:ok, _} = Reviews.submit(real["id"], @session, nil, @other, 5, "Me ayudó")
    assert {:ok, _} = Reviews.submit(real["id"], @session, nil, @other, 1, "Duplicada")
    assert Metrics.today().totals.reviews == 1
    assert Metrics.today().totals.rating == 5.0
    assert Metrics.today().totals.consultations == 1
    assert Repo.aggregate(Review, :count) == 2
  end

  test "review validation, ownership and limits cannot be bypassed by changing a case id" do
    {:ok, item} = Cases.create("Hola", @session, nil)
    assert {:error, 404, _} = Reviews.submit(item["id"], @other, nil, @other, 5, "")
    assert {:error, 400, _} = Reviews.submit(item["id"], @session, nil, @other, 6, "")
    assert {:error, 400, _} = Reviews.submit(item["id"], @session, nil, @other, 5, nil)

    assert {:error, 400, _} =
             Reviews.submit(item["id"], @session, nil, @other, 5, String.duplicate("é", 501))

    for _ <- 1..3 do
      {:ok, item} = Cases.create("Hola", @session, nil)
      assert {:ok, _} = Reviews.submit(item["id"], @session, nil, @other, 4, "")
    end

    {:ok, item} = Cases.create("Hola", @session, nil)
    assert {:error, 429, _} = Reviews.submit(item["id"], @session, nil, @other, 4, "")
    assert Repo.aggregate(Review, :count) == 3
  end

  test "comments are private, removable, and never returned in public stats" do
    {:ok, item} = Cases.create("Hola", @session, nil)
    Reviews.submit(item["id"], @session, nil, @other, 5, "PRIVATE_REVIEW")
    refute Jason.encode!(Metrics.today()) =~ "PRIVATE_REVIEW"
    assert {:error, 404, _} = Reviews.delete(item["id"], @other, nil)
    assert {:ok, _} = Reviews.delete(item["id"], @session, nil)
    assert Repo.one!(Review).comment == ""
    Reviews.submit(item["id"], @session, nil, @other, 1, "Otra")
    assert Metrics.today().totals.reviews == 1
    assert Repo.one!(Review).comment == ""
  end

  test "account deletion removes comments while anonymous aggregates survive" do
    owner = Cases.profile(%{issuer: "https://issuer.example", subject: "reviewer"})
    {:ok, item} = Cases.create("Hola", @session, owner)
    Reviews.submit(item["id"], @session, owner, @other, 4, "PRIVATE_REVIEW")
    Repo.delete!(owner)
    assert Repo.aggregate(Review, :count) == 0
    assert Metrics.today().totals.reviews == 1
  end

  test "unrelated questions never call the model or consume AI budget" do
    Application.put_env(:everyday_trust, :ai_provider, "meta")
    Application.put_env(:everyday_trust, :ai_key, "synthetic-key")
    Application.put_env(:everyday_trust, :ai_data_approved, true)
    Application.put_env(:everyday_trust, :test_model_request, fn _, _ ->
      flunk("Unexpected model call")
    end)

    on_exit(fn ->
      for key <- [:ai_provider, :ai_key, :ai_data_approved, :test_model_request],
          do: Application.delete_env(:everyday_trust, key)
    end)

    reply =
      EverydayTrust.Interpreter.followup(
        EverydayTrust.Analysis.run("Hola"),
        "Escribe un poema sobre fútbol",
        []
      )

    assert reply =~ "esta consulta"
    assert Repo.query!("SELECT count(*) FROM quota_buckets WHERE key LIKE 'ai:%'").rows == [[0]]
  end
end
