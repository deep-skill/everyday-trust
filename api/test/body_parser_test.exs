defmodule EverydayTrustWeb.BodyParserTest do
  use ExUnit.Case, async: false
  import Plug.Test
  import Plug.Conn

  alias EverydayTrustWeb.BodyParser

  setup do
    original = Application.fetch_env(:everyday_trust, :image_input_enabled)

    on_exit(fn ->
      case original do
        {:ok, value} -> Application.put_env(:everyday_trust, :image_input_enabled, value)
        :error -> Application.delete_env(:everyday_trust, :image_input_enabled)
      end
    end)

    :ok
  end

  test "only the enabled exact image route receives the larger JSON limit" do
    Application.put_env(:everyday_trust, :image_input_enabled, true)
    body = Jason.encode!(%{image: String.duplicate("A", 40_000)})
    assert parse(:post, "/api/v1/image-cases", body).body_params["image"] != nil

    for {method, path} <- [
          {:post, "/api/v1/cases"},
          {:post, "/api/v1/cases/image"},
          {:post, "/api/v1/image-cases/extra"},
          {:put, "/api/v1/image-cases"}
        ] do
      assert_raise Plug.Parsers.RequestTooLargeError, fn -> parse(method, path, body) end
    end
  end

  test "the disabled image route keeps the original body limit" do
    Application.put_env(:everyday_trust, :image_input_enabled, false)
    body = Jason.encode!(%{image: String.duplicate("A", 40_000)})

    assert_raise Plug.Parsers.RequestTooLargeError, fn ->
      parse(:post, "/api/v1/image-cases", body)
    end
  end

  test "even the enabled image route rejects bodies above three MiB" do
    Application.put_env(:everyday_trust, :image_input_enabled, true)
    body = Jason.encode!(%{image: String.duplicate("A", 3_145_728)})

    assert_raise Plug.Parsers.RequestTooLargeError, fn ->
      parse(:post, "/api/v1/image-cases", body)
    end
  end

  defp parse(method, path, body) do
    conn(method, path, body)
    |> put_req_header("content-type", "application/json")
    |> BodyParser.call(BodyParser.init([]))
  end
end
