defmodule EverydayTrust.ImageInputTest do
  use ExUnit.Case, async: false
  import ExUnit.CaptureLog

  alias EverydayTrust.ImageInput

  setup do
    keys = [:image_input_enabled, :ai_provider, :ai_key, :ai_data_approved, :test_image_request]
    original = Map.new(keys, &{&1, Application.fetch_env(:everyday_trust, &1)})
    Application.put_env(:everyday_trust, :image_input_enabled, true)
    Application.put_env(:everyday_trust, :ai_provider, "meta")
    Application.put_env(:everyday_trust, :ai_key, "synthetic-image-key")
    Application.put_env(:everyday_trust, :ai_data_approved, true)

    on_exit(fn ->
      Enum.each(original, fn
        {key, {:ok, value}} -> Application.put_env(:everyday_trust, key, value)
        {key, :error} -> Application.delete_env(:everyday_trust, key)
      end)
    end)

    :ok
  end

  test "PNG data URL yields dimensions and a struct that hides its image when inspected" do
    data = png(2, 3)
    assert {:ok, image} = ImageInput.validate(data_url("image/png", data))
    assert image.mime == "image/png"
    assert image.width == 2
    assert image.height == 3
    assert image.bytes == byte_size(data)
    refute inspect(image) =~ "base64"
  end

  test "JPEG and WebP signatures must agree with their declared MIME" do
    jpeg = jpeg(8, 6)
    webp = webp(7, 4)
    assert {:ok, %{width: 8, height: 6}} = ImageInput.validate(data_url("image/jpeg", jpeg))
    assert {:ok, %{width: 7, height: 4}} = ImageInput.validate(data_url("image/webp", webp))
    assert {:error, :invalid_image} = ImageInput.validate(data_url("image/png", jpeg))
    assert {:error, :invalid_image} = ImageInput.validate(data_url("image/jpeg", webp))
  end

  test "remote URLs, unsupported MIME, invalid base64 and malformed files are rejected" do
    for value <- [
          "https://images.example/screenshot.png",
          "data:image/svg+xml;base64," <> Base.encode64("<svg/>"),
          "data:image/png;base64,NOT BASE64",
          "data:image/png;base64," <> Base.encode64("not a picture"),
          data_url("image/png", binary_part(png(1, 1), 0, 30)),
          data_url("image/png", png(1, 1) <> "trailing metadata")
        ] do
      assert {:error, :invalid_image} = ImageInput.validate(value)
    end
  end

  test "both dimensions must fit 1280 and oversized input is rejected before a provider call" do
    assert {:ok, _} = ImageInput.validate(data_url("image/png", png(1_280, 1)))
    assert {:error, :dimensions} = ImageInput.validate(data_url("image/png", png(1_281, 1)))
    assert {:error, :dimensions} = ImageInput.validate(data_url("image/jpeg", jpeg(1, 1_281)))
    assert {:error, :dimensions} = ImageInput.validate(data_url("image/webp", webp(1_281, 1)))
    assert {:error, :too_large} = ImageInput.validate("data:image/png;base64," <> String.duplicate("A", 2_796_240))
    assert {:error, :too_large} = ImageInput.validate(data_url("image/png", :binary.copy(<<0>>, 2_097_153)))
  end

  test "EXIF and textual metadata are rejected for all accepted formats" do
    assert {:error, :metadata} = ImageInput.validate(data_url("image/png", png(1, 1, chunk("eXIf", "GPS PRIVATE"))))
    assert {:error, :metadata} = ImageInput.validate(data_url("image/png", png(1, 1, chunk("iTXt", "PRIVATE"))))
    jpeg = <<0xFF, 0xD8, 0xFF, 0xE1, 8::16, "Exif", 0, 0>> <> binary_part(jpeg(1, 1), 2, byte_size(jpeg(1, 1)) - 2)
    assert {:error, :metadata} = ImageInput.validate(data_url("image/jpeg", jpeg))
    assert {:error, :metadata} = ImageInput.validate(data_url("image/webp", webp(1, 1, riff_chunk("EXIF", "PRIVATE"))))
    assert {:error, :metadata} = ImageInput.validate(data_url("image/png", png(1, 1, chunk("acTL", <<1::32, 0::32>>))))
  end

  test "disabled feature never contacts the provider" do
    Application.put_env(:everyday_trust, :image_input_enabled, false)
    assert {:error, :disabled} = ImageInput.validate(data_url("image/png", png(1, 1)))
    assert {:error, :disabled} = ImageInput.extract(%ImageInput{})
  end

  test "OCR makes one bounded Meta vision request and returns only structured text" do
    parent = self()
    Application.put_env(:everyday_trust, :test_image_request, fn url, options ->
      send(parent, {:request, url, options})
      provider_response(%{text: "BANCO EJEMPLO: valida en https://acceso.example", no_text: false})
    end)

    {:ok, image} = ImageInput.validate(data_url("image/png", png(2, 2)))
    assert {:ok, %{text: "BANCO EJEMPLO: valida en https://acceso.example", no_text: false}} = ImageInput.extract(image)
    assert_received {:request, "https://api.meta.ai/v1/chat/completions", options}
    assert options[:retry] == false
    assert options[:redirect] == false
    assert options[:json].model == "muse-spark-1.3-contributor"
    assert options[:json].max_tokens == 1_800
    assert [%{role: "system"}, %{role: "user", content: [_, %{type: "image_url", image_url: %{url: data}}]}] = options[:json].messages
    assert data == image.data_url
    refute_received {:request, _, _}
  end

  test "a screenshot without readable text produces an explicit no_text result" do
    Application.put_env(:everyday_trust, :test_image_request, fn _, _ ->
      provider_response(%{text: "", no_text: true})
    end)

    {:ok, image} = ImageInput.validate(data_url("image/png", png(1, 1)))
    assert {:ok, %{text: "", no_text: true}} = ImageInput.extract(image)
  end

  test "invalid or excessive model output is rejected and cannot become a normal message" do
    {:ok, image} = ImageInput.validate(data_url("image/png", png(1, 1)))

    for output <- [
          %{text: String.duplicate("x", 5_001), no_text: false},
          %{text: "Invented despite no_text", no_text: true},
          %{text: "", no_text: false},
          %{text: "Hola", no_text: "false"},
          %{text: ["wrong"], no_text: false}
        ] do
      Application.put_env(:everyday_trust, :test_image_request, fn _, _ -> provider_response(output) end)
      assert {:error, :invalid_response} = ImageInput.extract(image)
    end
  end

  test "provider exceptions do not log image or original screenshot data" do
    Application.put_env(:everyday_trust, :test_image_request, fn _, options ->
      raise "SYNTHETIC_PRIVATE_IMAGE #{inspect(options[:json])}"
    end)

    {:ok, image} = ImageInput.validate(data_url("image/png", png(1, 1)))
    log = capture_log(fn -> assert {:error, :provider_unavailable} = ImageInput.extract(image) end)
    refute log =~ "SYNTHETIC_PRIVATE_IMAGE"
    refute log =~ image.data_url
  end

  test "a different provider and missing key cannot silently send an image elsewhere" do
    {:ok, image} = ImageInput.validate(data_url("image/png", png(1, 1)))
    Application.put_env(:everyday_trust, :ai_provider, "deepseek")
    assert {:error, :disabled} = ImageInput.extract(image)
    Application.put_env(:everyday_trust, :ai_provider, "meta")
    Application.delete_env(:everyday_trust, :ai_key)
    assert {:error, :provider_unavailable} = ImageInput.extract(image)
  end

  defp data_url(mime, binary), do: "data:#{mime};base64," <> Base.encode64(binary)

  defp png(width, height, extra \\ <<>>) do
    header = <<width::32, height::32, 8, 2, 0, 0, 0>>
    rows = :binary.copy(<<0>> <> :binary.copy(<<0, 0, 0>>, width), height)
    <<137, 80, 78, 71, 13, 10, 26, 10>> <>
      chunk("IHDR", header) <> extra <> chunk("IDAT", :zlib.compress(rows)) <> chunk("IEND", <<>>)
  end

  defp chunk(type, payload),
    do: <<byte_size(payload)::32, type::binary, payload::binary, :erlang.crc32(type <> payload)::32>>

  defp jpeg(width, height) do
    <<0xFF, 0xD8, 0xFF, 0xC0, 11::16, 8, height::16, width::16, 1, 1, 0x11, 0,
      0xFF, 0xDA, 8::16, 1, 1, 0, 0, 63, 0, 0, 0xFF, 0xD9>>
  end

  defp webp(width, height, extra \\ <<>>) do
    payload = <<0x2F, ((height - 1) * 16_384 + width - 1)::little-32, 0>>
    chunks = riff_chunk("VP8L", payload) <> extra
    <<"RIFF", (byte_size(chunks) + 4)::little-32, "WEBP", chunks::binary>>
  end

  defp riff_chunk(type, payload) do
    <<type::binary, byte_size(payload)::little-32, payload::binary>> <>
      if(rem(byte_size(payload), 2) == 1, do: <<0>>, else: <<>>)
  end

  defp provider_response(output),
    do: {:ok, %{status: 200, body: %{"choices" => [%{"message" => %{"content" => Jason.encode!(output)}}]}}}
end
