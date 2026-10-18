defmodule EverydayTrust.CasesTest do
  use ExUnit.Case, async: false
  alias EverydayTrust.{Cases, Repo, Case, SavedCase}
  @session String.duplicate("a", 64)
  @other String.duplicate("b", 64)
  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Repo, {:shared, self()})
    :ok
  end

  defp owner(subject), do: Cases.profile(%{issuer: "https://issuer.example", subject: subject})

  test "anonymous case access requires original session" do
    {:ok, result} = Cases.create("Hola", @session, nil)
    assert {:ok, _} = Cases.get(result["id"], @session, nil)
    assert {:error, 404, _} = Cases.get(result["id"], @other, nil)
    assert {:error, 404, _} = Cases.get("invalid", @session, nil)
  end

  test "authenticated cases cannot be read after logout or by another account" do
    first = owner("first")
    second = owner("second")
    {:ok, result} = Cases.create("Hola", @session, first)
    assert {:error, 404, _} = Cases.get(result["id"], @session, nil)
    assert {:error, 404, _} = Cases.get(result["id"], @session, second)
    assert {:ok, _} = Cases.get(result["id"], @other, first)
  end

  test "saving is voluntary, idempotent, bound to account and deletes atomically" do
    first = owner("first")
    second = owner("second")
    {:ok, result} = Cases.create("Hola", @session, nil)
    assert Cases.history(first, nil).items == []
    {:ok, saved} = Cases.save(result["id"], @session, first)
    assert {:ok, ^saved} = Cases.save(result["id"], @session, first)
    assert Repo.aggregate(SavedCase, :count) == 1
    assert {:error, 404, _} = Cases.save(result["id"], @session, second)
    assert {:error, 404, _} = Cases.saved(saved["id"], second)
    assert {:error, 404, _} = Cases.delete(saved["id"], second)
    assert {:ok, _} = Cases.delete(saved["id"], first)
    assert Cases.history(first, nil).items == []
  end

  test "original message, phone and URL path are never persisted" do
    {:ok, result} =
      Cases.create(
        "SYNTHETICPERSON mi DNI 12345678, llama +51 999 123 456 https://www.viabcp.com/private?customer=SYNTHETICSECRET",
        @session,
        nil
      )

    item = Repo.get!(Case, result["id"])
    stored = Jason.encode!(%{result: item.result, context: item.context})

    for value <- ["SYNTHETICPERSON", "12345678", "999 123 456", "private", "SYNTHETICSECRET"] do
      refute String.contains?(stored, value)
    end
  end

  test "expired case is inaccessible before cleanup" do
    {:ok, result} = Cases.create("Hola", @session, nil)
    item = Repo.get!(Case, result["id"])
    Repo.update!(Ecto.Changeset.change(item, expires_at: DateTime.add(DateTime.utc_now(), -1)))
    assert {:error, 404, _} = Cases.get(result["id"], @session, nil)
    Cases.cleanup()
    refute Repo.get(Case, result["id"])
  end

  test "atomic quota limits concurrent requests" do
    allowed =
      1..20
      |> Task.async_stream(fn _ -> Cases.quota(@session, nil, "test", 5) end, max_concurrency: 10)
      |> Enum.count(&(&1 == {:ok, true}))

    assert allowed == 5
  end

  test "anonymous limit and turn limit are enforced" do
    for _ <- 1..5, do: assert({:ok, _} = Cases.create("Hola", @session, nil))
    assert {:error, 429, _} = Cases.create("Hola", @session, nil)
    {:ok, result} = Cases.create("Hola", @other, nil)

    for _ <- 1..5 do
      assert {:ok, %{reply: reply}} =
               Cases.message(result["id"], @other, nil, "", ["shared_data", "paid"])

      assert String.contains?(reply, "datos y realizaste un pago")
    end

    assert {:error, 429, _} = Cases.message(result["id"], @other, nil, "Otra pregunta", [])
  end

  test "feedback is idempotent and has a closed schema" do
    {:ok, result} = Cases.create("Hola", @session, nil)
    assert {:ok, _} = Cases.feedback(result["id"], @session, nil, "helpful")
    assert {:ok, _} = Cases.feedback(result["id"], @session, nil, "unhelpful")
    assert Repo.get!(Case, result["id"]).feedback == "helpful"
    assert {:error, 400, _} = Cases.feedback(result["id"], @session, nil, "free text")
  end

  test "feedback aggregates survive cleanup and demos stay separate" do
    {:ok, result} = Cases.create("Hola", @session, nil, demo: true)
    Cases.feedback(result["id"], @session, nil, "helpful")
    Cases.feedback(result["id"], @session, nil, "unhelpful")
    item = Repo.get!(Case, result["id"])
    Repo.update!(Ecto.Changeset.change(item, expires_at: DateTime.add(DateTime.utc_now(), -1)))
    Cases.cleanup()
    stats = EverydayTrust.Metrics.today()
    assert stats.demos["completed"] == 1
    assert stats.demos["helpful"] == 1
    refute stats.demos["unhelpful"]
    refute stats.queries["completed"]
  end

  test "rejected member quota does not consume network or global quota" do
    for _ <- 1..5, do: Cases.create("Hola", @session, nil)
    assert {:error, 429, _} = Cases.create("Hola", @session, nil, network: @other)

    assert Repo.query!(
             "SELECT count(*) FROM quota_buckets WHERE key LIKE 'network:%' OR key LIKE 'all_analyses:%'"
           ).rows == [[0]]
  end

  test "pending timeout finishes once and never turns an incomplete result green" do
    {:ok, result} = Cases.create("Hola", @session, nil)
    item = Repo.get!(Case, result["id"])

    pending =
      item.result
      |> Map.put("verdict", "no_signals_detected")
      |> Map.put("analysis_status", "in_progress")

    Repo.update!(
      Ecto.Changeset.change(item,
        result: pending,
        analysis_pending: true,
        analysis_deadline: DateTime.add(DateTime.utc_now(), -1)
      )
    )

    assert {:ok, finished} = Cases.get(item.id, @session, nil)
    assert finished.result["analysis_status"] == "completed"
    assert finished.result["verdict"] == "inconclusive"
    count = EverydayTrust.Metrics.today().queries["completed"]
    Cases.finish(item.id, pending)
    assert EverydayTrust.Metrics.today().queries["completed"] == count
  end

  test "invalid interaction returns 400 without consuming a turn" do
    {:ok, result} = Cases.create("Hola", @session, nil)
    assert {:error, 400, _} = Cases.message(result["id"], @session, nil, "", ["invented"])
    assert {:error, 400, _} = Cases.message(result["id"], @session, nil, "", ["paid", "paid"])
    assert Repo.get!(Case, result["id"]).turns == 0
  end
end
