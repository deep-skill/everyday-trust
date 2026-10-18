defmodule EverydayTrust.CasesTest do
  use ExUnit.Case, async: false
  alias EverydayTrust.{Cases, Repo, Case, SavedCase, Analysis}
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

  test "checked redirect hosts never persist identifying subdomains" do
    {:ok, result} =
      Cases.create("https://SYNTHETICPERSON.customer.example/private?token=SECRET", @session, nil)

    stored = Repo.get!(Case, result["id"]) |> Map.fetch!(:result) |> Jason.encode!()
    refute stored =~ "syntheticperson"
    refute stored =~ "SECRET"
    refute stored =~ "private"
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

  test "AI runs after the initial response and persists only final structured output" do
    parent = self()
    Application.put_env(:everyday_trust, :ai_provider, "deepseek")
    Application.put_env(:everyday_trust, :ai_key, "synthetic-test-key")
    Application.put_env(:everyday_trust, :ai_data_approved, true)

    Application.put_env(:everyday_trust, :test_model_request, fn _, options ->
      send(parent, {:model_started, self(), Jason.encode!(options[:json])})

      receive do
        :finish -> :ok
      after
        1000 -> :ok
      end

      {:ok,
       %{
         status: 200,
         body: %{
           "choices" => [
             %{
               "message" => %{
                 "content" =>
                   Jason.encode!(%{
                     "suggested_verdict" => "high_risk",
                     "scam_type" => "family_emergency",
                     "cited_signal_ids" => []
                   })
               }
             }
           ]
         }
       }}
    end)

    on_exit(fn ->
      for key <- [:ai_provider, :ai_key, :ai_data_approved, :test_model_request],
          do: Application.delete_env(:everyday_trust, key)
    end)

    {:ok, result} = Cases.create("Tu código es 4821", @session, nil)
    assert result["analysis_status"] == "in_progress"
    assert {:error, 409, _} = Cases.save(result["id"], @session, owner("async-owner"))
    assert_receive {:model_started, pid, payload}, 500
    refute payload =~ "4821"
    send(pid, :finish)

    for _ <- 1..30 do
      if Repo.get!(Case, result["id"]).analysis_pending, do: Process.sleep(10)
    end

    {:ok, item} = Cases.get(result["id"], @session, nil)
    assert item.result["analysis_status"] == "completed"
    assert item.result["revision"] == 2
    assert item.result["verdict"] == "suspicious"
    assert EverydayTrust.Metrics.today().queries["completed"] == 1
    refute Jason.encode!(item.result) =~ "4821"
  end

  describe "Contributor internal full-context pilot" do
    setup do
      Application.put_env(:everyday_trust, :ai_provider, "meta")
      Application.put_env(:everyday_trust, :ai_key, "synthetic-test-key")
      Application.put_env(:everyday_trust, :ai_data_approved, true)

      on_exit(fn ->
        for key <- [:ai_provider, :ai_key, :ai_data_approved, :test_model_request],
            do: Application.delete_env(:everyday_trust, key)
      end)

      :ok
    end

    test "complete message and all analysis reach the model" do
      parent = self()

      Application.put_env(:everyday_trust, :test_model_request, fn _, options ->
        input =
          options[:json][:messages] |> List.last() |> Map.fetch!(:content) |> Jason.decode!()

        send(parent, {:contributor, input})

        model_response(%{
          "suggested_verdict" => "inconclusive",
          "scam_type" => "undetermined",
          "cited_signal_ids" => []
        })
      end)

      text =
        "SYNTHETICPERSON clave 4821, DNI 12345678, https://secret.example/private?token=SECRET"

      base = Analysis.run(text)
      result = EverydayTrust.Interpreter.enrich(base, text)
      assert result["coverage"]["ai"] == "completed"
      assert_received {:contributor, payload}
      assert payload["message"] == text
      assert payload["analysis"] == base
      refute Jason.encode!(result) =~ "SYNTHETICPERSON"
      refute Jason.encode!(result) =~ "SECRET"
    end

    test "async task preserves original input without persisting it" do
      parent = self()

      Application.put_env(:everyday_trust, :test_model_request, fn _, options ->
        input =
          options[:json][:messages] |> List.last() |> Map.fetch!(:content) |> Jason.decode!()

        send(parent, {:contributor, input})

        model_response(%{
          "suggested_verdict" => "suspicious",
          "scam_type" => "other",
          "cited_signal_ids" => []
        })
      end)

      text = "INTERNAL_FIXTURE mensaje completo https://fixture.example/path?recipient=TESTVALUE"
      {:ok, result} = Cases.create(text, @session, nil)
      assert_receive {:contributor, payload}, 500
      assert payload["message"] == text
      assert Map.has_key?(payload["analysis"], "domains")
      assert Map.has_key?(payload["analysis"], "coverage")

      for _ <- 1..30 do
        if Repo.get!(Case, result["id"]).analysis_pending, do: Process.sleep(10)
      end

      row = Repo.get!(Case, result["id"])
      refute row.analysis_pending

      for marker <- ["INTERNAL_FIXTURE", "TESTVALUE"],
          do: refute(Jason.encode!(row.result) <> row.context =~ marker)
    end

    test "maximum Unicode input is preserved within the full-context budget" do
      parent = self()
      text = String.duplicate("🗻", 5000)

      Application.put_env(:everyday_trust, :test_model_request, fn _, options ->
        input =
          options[:json][:messages] |> List.last() |> Map.fetch!(:content) |> Jason.decode!()

        send(parent, {:complete_input, input["message"]})

        model_response(%{
          "suggested_verdict" => "inconclusive",
          "scam_type" => "undetermined",
          "cited_signal_ids" => []
        })
      end)

      result = EverydayTrust.Interpreter.enrich(Analysis.run(""), text)
      assert result["coverage"]["ai"] == "completed"
      assert_received {:complete_input, ^text}
    end

    test "follow-up sends the complete question and available case context" do
      parent = self()

      Application.put_env(:everyday_trust, :test_model_request, fn _, options ->
        input =
          options[:json][:messages] |> List.last() |> Map.fetch!(:content) |> Jason.decode!()

        send(parent, {:followup_context, input})
        model_response(%{"intent" => "verify_identity", "cited_signal_ids" => []})
      end)

      base = Analysis.run("Un mensaje de prueba.")
      question = "¿Cómo verifico https://fixture.example/full/path?code=FICTIONAL?"
      reply = EverydayTrust.Interpreter.followup(base, question, [])
      assert reply =~ "canal independiente"
      assert_received {:followup_context, payload}
      assert payload["question"] == question
      assert payload["case"] == base
    end
  end

  defp model_response(output) do
    {:ok,
     %{status: 200, body: %{"choices" => [%{"message" => %{"content" => Jason.encode!(output)}}]}}}
  end
end
