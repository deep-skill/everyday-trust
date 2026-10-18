defmodule EverydayTrust.DestinationTest do
  use ExUnit.Case, async: false
  alias EverydayTrust.{Destination, Signals}

  setup do
    Application.put_env(:everyday_trust, :test_destination_dns, fn _ ->
      {:ok, [{93, 184, 216, 34}]}
    end)

    on_exit(fn ->
      Application.delete_env(:everyday_trust, :test_destination_dns)
      Application.delete_env(:everyday_trust, :test_destination_head)
    end)

    :ok
  end

  for ip <- [
        {0, 0, 0, 0},
        {10, 0, 0, 1},
        {127, 0, 0, 1},
        {100, 64, 0, 1},
        {169, 254, 169, 254},
        {172, 16, 0, 1},
        {192, 168, 1, 1},
        {192, 0, 0, 1},
        {192, 0, 2, 1},
        {198, 18, 0, 1},
        {198, 51, 100, 1},
        {203, 0, 113, 1},
        {224, 0, 0, 1},
        {255, 255, 255, 255},
        {0, 0, 0, 0, 0, 0, 0, 1}
      ] do
    test "nonpublic destination #{inspect(ip)} is rejected" do
      refute Destination.public_ip?(unquote(Macro.escape(ip)))
    end
  end

  test "only the origin is requested and its validated address is pinned" do
    parent = self()

    Application.put_env(:everyday_trust, :test_destination_head, fn uri, ip ->
      send(parent, {:head, uri, ip})
      {:ok, 200, nil}
    end)

    result =
      Destination.check(
        Signals.parse("https://safe.example/customer/SECRET?token=PRIVATE#fragment")
      )

    assert result.status == "completed"

    assert_received {:head, %URI{host: "safe.example", path: "/", query: nil, fragment: nil},
                     {93, 184, 216, 34}}

    refute Jason.encode!(result) =~ "SECRET"
    refute Jason.encode!(result) =~ "PRIVATE"
  end

  test "mixed DNS answers cannot reach private addresses" do
    parent = self()

    Application.put_env(:everyday_trust, :test_destination_dns, fn _ ->
      {:ok, [{93, 184, 216, 34}, {10, 0, 0, 1}]}
    end)

    Application.put_env(:everyday_trust, :test_destination_head, fn _, _ ->
      send(parent, :requested)
      {:ok, 200, nil}
    end)

    assert Destination.check(Signals.parse("https://mixed.example")).status == "blocked"
    refute_received :requested
  end

  test "redirects are validated again before touching metadata endpoints" do
    parent = self()

    Application.put_env(:everyday_trust, :test_destination_dns, fn
      "safe.example" -> {:ok, [{93, 184, 216, 34}]}
      _ -> {:ok, [{169, 254, 169, 254}]}
    end)

    Application.put_env(:everyday_trust, :test_destination_head, fn uri, _ ->
      send(parent, {:requested, uri.host})
      {:ok, 302, "https://169.254.169.254/latest/meta-data/"}
    end)

    assert Destination.check(Signals.parse("https://safe.example")).status == "blocked"
    assert_received {:requested, "safe.example"}
    refute_received {:requested, "169.254.169.254"}
  end

  test "each redirect origin loses its path and query" do
    parent = self()

    Application.put_env(:everyday_trust, :test_destination_head, fn uri, _ ->
      send(parent, {:origin, uri.host, uri.path, uri.query})

      if uri.host == "first.example",
        do: {:ok, 301, "https://next.example/private?recipient=SECRET"},
        else: {:ok, 200, nil}
    end)

    assert %{status: "completed", hosts: ["first.example", "next.example"]} =
             Destination.check(Signals.parse("https://first.example/initial?secret=ONE"))

    assert_received {:origin, "first.example", "/", nil}
    assert_received {:origin, "next.example", "/", nil}
  end

  test "same-origin redirects do not request an account path" do
    parent = self()

    Application.put_env(:everyday_trust, :test_destination_head, fn _, _ ->
      send(parent, :head)
      {:ok, 302, "/account?code=SECRET"}
    end)

    assert Destination.check(Signals.parse("https://safe.example")).status == "completed"
    assert_received :head
    refute_received :head
  end

  test "HTTPS redirects cannot downgrade the probe to HTTP" do
    parent = self()

    Application.put_env(:everyday_trust, :test_destination_head, fn uri, _ ->
      send(parent, {:requested, uri.scheme})
      {:ok, 302, "http://next.example/"}
    end)

    assert Destination.check(Signals.parse("https://safe.example")).status == "partial"
    assert_received {:requested, "https"}
    refute_received {:requested, "http"}
  end

  for url <- [
        "https://user:pass@safe.example",
        "https://safe.example:8443",
        "http://localhost",
        "http://app.internal",
        "https://[::1]"
      ] do
    test "unsafe URL is blocked before a request #{url}" do
      parent = self()

      Application.put_env(:everyday_trust, :test_destination_head, fn _, _ ->
        send(parent, :requested)
        {:ok, 200, nil}
      end)

      assert Destination.check(Signals.parse(unquote(url))).status == "blocked"
      refute_received :requested
    end
  end

  test "NXDOMAIN is reported without requesting a site" do
    Application.put_env(:everyday_trust, :test_destination_dns, fn _ -> {:error, :nxdomain} end)
    assert Destination.check(Signals.parse("https://absent.example")).status == "not_found"
  end
end
