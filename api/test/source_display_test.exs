defmodule EverydayTrust.SourceDisplayTest do
  use ExUnit.Case, async: false

  alias EverydayTrust.SourceDisplay

  @report "https://urlscan.io/result/11111111-1111-4111-8111-111111111111/"

  setup do
    :sys.replace_state(SourceDisplay, fn _ -> %{} end)
    :ok
  end

  test "only registrable hosts and report identifiers survive persistence sanitization" do
    original = result()
    sanitized = SourceDisplay.sanitize(original)
    serialized = Jason.encode!(sanitized)
    refute serialized =~ "SYNTHETICPERSON"
    refute serialized =~ "PRIVATE-TITLE"
    refute serialized =~ "PRIVATE-BRAND"
    refute serialized =~ "PRIVATE-EXTRA"

    assert [%{"hostname" => "example.com", "final_hostname" => "example.net"}] =
             sanitized["url_scans"]

    assert hd(sanitized["url_scans"])["report_url"] == @report
  end

  test "title and brands are restored only for the matching case and report identifier" do
    original = result()
    SourceDisplay.put("case-one", original)
    sanitized = SourceDisplay.sanitize(original)

    assert hd(SourceDisplay.restore("case-one", sanitized)["url_scans"])["page_title"] ==
             "PRIVATE-TITLE"

    refute hd(SourceDisplay.restore("case-other", sanitized)["url_scans"])["page_title"]

    other =
      put_in(sanitized, ["url_scans"], [
        %{"report_url" => "https://urlscan.io/result/22222222-2222-4222-8222-222222222222/"}
      ])

    refute hd(SourceDisplay.restore("case-one", other)["url_scans"])["page_title"]
  end

  test "expired display data is discarded and the cache stays bounded" do
    for n <- 1..1_001, do: SourceDisplay.put("case-#{n}", result())
    assert map_size(:sys.get_state(SourceDisplay)) == 1_000

    :sys.replace_state(SourceDisplay, fn _ ->
      %{
        "expired" =>
          {System.monotonic_time(:millisecond) - 1,
           %{@report => %{"page_title" => "PRIVATE-TITLE"}}}
      }
    end)

    sanitized = SourceDisplay.sanitize(result())
    refute hd(SourceDisplay.restore("expired", sanitized)["url_scans"])["page_title"]
    assert :sys.get_state(SourceDisplay) == %{}
  end

  defp result do
    %{
      "verdict" => "suspicious",
      "url_scans" => [
        %{
          "hostname" => "SYNTHETICPERSON.customer.example.com",
          "domain" => "example.com",
          "final_hostname" => "SYNTHETICPERSON.customer.example.net",
          "page_title" => "PRIVATE-TITLE",
          "brands" => ["PRIVATE-BRAND"],
          "extra" => "PRIVATE-EXTRA",
          "report_url" => @report,
          "status" => "matched",
          "checked_at" => "2026-10-18T13:00:00Z"
        }
      ]
    }
  end
end
