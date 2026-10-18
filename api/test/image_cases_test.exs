defmodule EverydayTrust.ImageCasesTest do
  use ExUnit.Case, async: false
  import ExUnit.CaptureLog
  alias EverydayTrust.{Case, Cases, Repo, SavedCase}

  @session String.duplicate("image-case-session-", 4)
  @network String.duplicate("image-case-network-", 4)

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Repo, {:shared, self()})

    keys = [
      :image_input_enabled,
      :ai_provider,
      :ai_key,
      :ai_data_approved,
      :test_image_request,
      :test_model_request,
      :safe_browsing_enabled,
      :urlscan_enabled,
      :network_checks
    ]

    original = Map.new(keys, &{&1, Application.fetch_env(:everyday_trust, &1)})
    Application.put_env(:everyday_trust, :image_input_enabled, true)
    Application.put_env(:everyday_trust, :ai_provider, "meta")
    Application.put_env(:everyday_trust, :ai_key, "synthetic-image-case-key")
    Application.put_env(:everyday_trust, :ai_data_approved, true)
    Application.put_env(:everyday_trust, :safe_browsing_enabled, false)
    Application.put_env(:everyday_trust, :urlscan_enabled, false)
    Application.put_env(:everyday_trust, :network_checks, false)
    parent = self()

    Application.put_env(:everyday_trust, :test_image_request, fn _, _ ->
      send(parent, :ocr_request)
      response("Un mensaje de prueba sin solicitudes ni enlaces.")
    end)

    Application.put_env(:everyday_trust, :test_model_request, fn _, _ ->
      send(parent, :unexpected_interpretation)
      {:error, :unexpected_second_model_call}
    end)

    on_exit(fn ->
      Enum.each(original, fn
        {key, {:ok, value}} -> Application.put_env(:everyday_trust, key, value)
        {key, :error} -> Application.delete_env(:everyday_trust, key)
      end)
    end)

    :ok
  end

  test "disabled and invalid uploads are rejected before consuming any quota or calling OCR" do
    Application.put_env(:everyday_trust, :image_input_enabled, false)
    assert {:error, 404, "image_disabled"} = create_image()
    Application.put_env(:everyday_trust, :image_input_enabled, true)

    assert {:error, 400, _} = Cases.create_image("not an image", "", @session, nil, @network)

    oversized = "data:image/png;base64," <> String.duplicate("A", 2_796_240)
    assert {:error, 413, _} = Cases.create_image(oversized, "", @session, nil, @network)
    assert Repo.query!("SELECT count(*) FROM quota_buckets").rows == [[0]]
    assert Repo.aggregate(Case, :count) == 0
    refute_received :ocr_request
  end

  test "two images spend four consultation units and leave exactly one anonymous text query" do
    assert {:ok, _} = create_image()
    assert {:ok, _} = create_image()
    assert quota_count("analysis", @session) == 4
    assert quota_count("network", @network) == 4
    assert quota_count("all_analyses", "global") == 4
    assert quota_count("ai", "global") == 2

    assert {:ok, _} =
             Cases.create("Hola", @session, nil, network: @network, skip_ai: true)

    assert {:error, 429, _} =
             Cases.create("Hola", @session, nil, network: @network, skip_ai: true)

    assert quota_count("analysis", @session) == 5
    assert quota_count("network", @network) == 5
    assert quota_count("all_analyses", "global") == 5
    assert_received :ocr_request
    assert_received :ocr_request
    refute_received :ocr_request
    refute_received :unexpected_interpretation
  end

  test "an exhausted AI budget rolls back the two analysis network and global reservations" do
    for _ <- 1..200, do: assert(Cases.quota("global", nil, "ai", 200))
    assert {:error, 429, _} = create_image()
    assert quota_count("ai", "global") == 200
    assert quota_count("analysis", @session) == 0
    assert quota_count("network", @network) == 0
    assert quota_count("all_analyses", "global") == 0
    assert Repo.aggregate(Case, :count) == 0
    refute_received :ocr_request
  end

  test "one OCR call is sufficient and neither capture nor extracted private text reaches storage or logs" do
    parent = self()
    image = png_data_url()
    original = "SYNTHETIC_PRIVATE_PERSON DNI 12345678: https://www.viabcp.com/private?customer=SYNTHETIC_PRIVATE_TOKEN"

    Application.put_env(:everyday_trust, :test_image_request, fn _, _ ->
      send(parent, :ocr_request)
      response(original)
    end)

    owner = Cases.profile(%{issuer: "https://issuer.example", subject: "image-case-owner"})

    log =
      capture_log(fn ->
        assert {:ok, result} =
                 Cases.create_image(image, "SYNTHETIC_EXTRA_NOTE", @session, owner, @network)

        assert result["analysis_status"] == "completed"
        assert {:ok, _} = Cases.save(result["id"], @session, owner)
        send(parent, {:image_result, result})
      end)

    assert_received {:image_result, result}
    item = Repo.get!(Case, result["id"])
    saved = Repo.one!(SavedCase)
    stored = Jason.encode!(%{result: item.result, context: item.context, saved: saved.result})

    for secret <- [
          image,
          "data:image/png;base64",
          "SYNTHETIC_PRIVATE_PERSON",
          "12345678",
          "SYNTHETIC_PRIVATE_TOKEN",
          "SYNTHETIC_EXTRA_NOTE",
          "/private"
        ] do
      refute stored =~ secret
      refute log =~ secret
    end

    assert quota_count("ai", "global") == 1
    assert_received :ocr_request
    refute_received :ocr_request
    refute_receive :unexpected_interpretation
  end

  test "unreadable images and provider failures create no case and retain their bounded charge" do
    Application.put_env(:everyday_trust, :test_image_request, fn _, _ -> response("", true) end)
    assert {:error, 422, _} = create_image()
    assert Repo.aggregate(Case, :count) == 0
    assert quota_count("analysis", @session) == 2
    assert quota_count("ai", "global") == 1

    Application.put_env(:everyday_trust, :test_image_request, fn _, _ ->
      {:error, :provider_unavailable}
    end)

    assert {:error, 503, _} = create_image()
    assert Repo.aggregate(Case, :count) == 0
    assert quota_count("analysis", @session) == 4
    assert quota_count("ai", "global") == 2
  end

  defp create_image,
    do: Cases.create_image(png_data_url(), "", @session, nil, @network)

  defp quota_count(operation, subject) do
    key = "#{operation}:#{Date.utc_today()}:#{subject}"

    case Repo.query!("SELECT count FROM quota_buckets WHERE key = $1", [key]).rows do
      [[count]] -> count
      [] -> 0
    end
  end

  defp png_data_url do
    header = <<2::32, 2::32, 8, 2, 0, 0, 0>>
    rows = :binary.copy(<<0, 0, 0, 0, 0, 0, 0>>, 2)

    png =
      <<137, 80, 78, 71, 13, 10, 26, 10>> <>
        chunk("IHDR", header) <>
        chunk("IDAT", :zlib.compress(rows)) <> chunk("IEND", <<>>)

    "data:image/png;base64," <> Base.encode64(png)
  end

  defp chunk(type, payload),
    do: <<byte_size(payload)::32, type::binary, payload::binary, :erlang.crc32(type <> payload)::32>>

  defp response(text, no_text \\ false),
    do:
      {:ok,
       %{
         status: 200,
         body: %{
           "choices" => [
             %{"message" => %{"content" => Jason.encode!(%{text: text, no_text: no_text})}}
           ]
         }
       }}
end
