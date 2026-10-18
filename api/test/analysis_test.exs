defmodule EverydayTrust.AnalysisTest do
  use ExUnit.Case, async: false
  alias EverydayTrust.{Analysis, Signals, Interpreter}

  setup do
    Application.put_env(:everyday_trust, :test_destination_dns, fn _ -> {:error, :unavailable} end)

    on_exit(fn -> Application.delete_env(:everyday_trust, :test_destination_dns) end)
    on_exit(fn -> Application.delete_env(:everyday_trust, :test_destination_head) end)
    on_exit(fn -> Application.delete_env(:everyday_trust, :test_http) end)
    on_exit(fn -> Application.put_env(:everyday_trust, :network_checks, false) end)
    :ok
  end

  for url <- ["https://www.viabcp.com", "www.viabcp.com", "https://www.sunat.gob.pe"] do
    test "official domain #{url}" do
      result = Analysis.run(unquote(url))
      assert result["verdict"] == "no_signals_detected"
      assert result["rules_score"] == 0
    end
  end

  test "a failed site check cannot produce a green result" do
    Application.put_env(:everyday_trust, :network_checks, true)
    result = Analysis.run("https://www.viabcp.com")
    assert result["verdict"] == "inconclusive"
    assert result["coverage"]["destination"] == "partial"
  end

  test "root redirects retain brand imitation signals from the next site" do
    Application.put_env(:everyday_trust, :network_checks, true)

    Application.put_env(:everyday_trust, :test_destination_dns, fn _ ->
      {:ok, [{93, 184, 216, 34}]}
    end)

    Application.put_env(:everyday_trust, :test_destination_head, fn uri, _ ->
      if uri.host == "www.viabcp.com",
        do: {:ok, 302, "https://bcp-acceso.example/private?person=SECRET"},
        else: {:ok, 200, nil}
    end)

    result = Analysis.run("https://www.viabcp.com")
    assert result["verdict"] == "suspicious"
    assert Enum.any?(result["signals"], &(&1["id"] == "brand_lookalike"))
    assert hd(result["domains"])["checked_hosts"] == ["viabcp.com", "bcp-acceso.example"]
    refute Jason.encode!(result) =~ "SECRET"
  end

  for url <- [
        "https://www.viabcp.com@192.0.2.1/login",
        "www.viabcp.com@attacker.example/login",
        "https://attacker.example@www.viabcp.com/login"
      ] do
    test "userinfo cannot earn trust #{url}" do
      result = Analysis.run(unquote(url))
      assert result["verdict"] != "no_signals_detected"
      assert Enum.any?(result["signals"], &(&1["id"] == "url_userinfo"))
    end
  end

  for url <- ["https://yаpe.com.pe", "yаpe.com.pe", "https://xn--ype-6cd.com.pe"] do
    test "international host is normalized #{url}" do
      result = Analysis.run(unquote(url))
      assert result["verdict"] != "no_signals_detected"
      assert Enum.any?(result["signals"], &(&1["id"] == "punycode"))
    end
  end

  for text <- [
        "Yapéame S/ 500: https://www.viabcp.com",
        "Soy tu hijo: https://www.viabcp.com",
        "+44 7700 900123 https://www.viabcp.com",
        "http://www.viabcp.com"
      ] do
    test "risk prevents green #{text}" do
      assert Analysis.run(unquote(text))["verdict"] != "no_signals_detected"
    end
  end

  for text <- [
        "Nunca compartas tu clave ni contraseña. Si alguien dice que ganaste un premio, no respondas.",
        "No debes compartir tu clave ni tu token.",
        "Ningún banco te pedirá tu contraseña.",
        "Nunca te pediremos tu clave."
      ] do
    test "safety warning is not a credential request #{text}" do
      refute Enum.any?(Signals.text(unquote(text)), &(&1["id"] == "asks_credentials"))
    end
  end

  for text <- [
        "Nunca compartas tu clave. Envíame tu clave ahora.",
        "No compartas tu clave, comparte tu contraseña conmigo.",
        "Nunca compartas tu clave con nadie, necesitamos tu clave para ayudarte.",
        "Ningún banco te pedirá tu clave, necesito tu contraseña."
      ] do
    test "later credential request remains visible #{text}" do
      assert Enum.any?(Signals.text(unquote(text)), &(&1["id"] == "asks_credentials"))
    end
  end

  test "all URLs including sixth are retained and risk cannot disappear" do
    urls =
      Enum.map(1..5, &"https://www.viabcp.com/path#{&1}") ++ ["https://bcp-acceso.example/clave"]

    result = Analysis.run(Enum.join(urls, " "))
    assert length(result["domains"]) == 6
    assert result["verdict"] in ["suspicious", "high_risk"]
    assert Enum.any?(result["signals"], &(&1["id"] == "incomplete_link_checks"))
  end

  test "URL punctuation, query, IPv4 and IPv6 survive extraction" do
    assert Signals.extract_urls("(https://example.com/a(b)).") == ["https://example.com/a(b)"]

    assert Signals.extract_urls("https://example.com?next=www.viabcp.com") == [
             "https://example.com?next=www.viabcp.com"
           ]

    assert length(Signals.extract_urls("https://192.0.2.1 https://[2001:db8::1]/")) == 2
  end

  for target <- [
        "https://victim.example/path?person=SYNTHETIC",
        "http://127.0.0.1:8080/internal",
        "https://www.viabcp.com"
      ] do
    test "redirect target is never requested #{target}" do
      parent = self()

      Application.put_env(:everyday_trust, :test_http, fn method, url ->
        send(parent, {:request, method, url})

        if url == "https://bit.ly/test",
          do: {:ok, %{status: 302, headers: %{"location" => [unquote(target)]}}},
          else: {:ok, %{status: 404, headers: %{}, body: %{}}}
      end)

      Signals.url("https://bit.ly/test", true)
      assert_received {:request, :head, "https://bit.ly/test"}
      refute_received {:request, _, unquote(target)}
    end
  end

  for target <- [
        "http://bit.ly/next",
        "https://bit.ly:8443/next",
        "https://user:pass@bit.ly/next",
        "javascript:alert(1)"
      ] do
    test "unsafe redirect hop is blocked #{target}" do
      parent = self()

      Application.put_env(:everyday_trust, :test_http, fn method, url ->
        send(parent, {:request, method, url})
        {:ok, %{status: 302, headers: %{"location" => [unquote(target)]}}}
      end)

      result = Signals.url("https://bit.ly/test", true)
      assert result["redirect_status"] == "unavailable"
      assert_received {:request, :head, "https://bit.ly/test"}
      refute_received {:request, _, unquote(target)}
    end
  end

  test "unknown text remains inconclusive" do
    assert Analysis.run("Nos vemos mañana en el parque.")["verdict"] == "inconclusive"
  end

  test "model cannot lower a deterministic verdict or invent evidence" do
    baseline =
      Analysis.run(
        "BCP: Tu cuenta será bloqueada. Ingresa tu clave en https://bcp-acceso.example"
      )

    assert baseline["verdict"] == "high_risk"

    assert Interpreter.apply_output(baseline, %{
             "suggested_verdict" => "no_signals_detected",
             "scam_type" => "undetermined",
             "cited_signal_ids" => []
           })["verdict"] == "high_risk"

    assert Interpreter.apply_output(baseline, %{
             "suggested_verdict" => "high_risk",
             "scam_type" => "bank_impersonation",
             "cited_signal_ids" => ["invented"]
           })["coverage"]["ai"] == "invalid_response"
  end

  test "AI-only high risk is capped at suspicious" do
    result =
      Analysis.run("Un mensaje sin señales conocidas.")
      |> Interpreter.apply_output(%{
        "suggested_verdict" => "high_risk",
        "scam_type" => "other",
        "cited_signal_ids" => []
      })

    assert result["verdict"] == "suspicious"
    assert result["risk_origin"] == "interpretation"
  end

  test "guidance responds to the case and rejects unrelated conversation" do
    result = Analysis.run("Hola mamá, cambié de número. Es urgente.")
    assert String.contains?(hd(result["advice"]), "familiar")

    assert String.contains?(
             Interpreter.followup(result, "¿Por qué es sospechoso?", []),
             "número nuevo"
           )

    assert String.contains?(Interpreter.followup(result, "Escribe un poema", []), "esta consulta")
  end

  test "network deadline never erases a locally detected imitation" do
    Application.put_env(:everyday_trust, :network_checks, true)

    Application.put_env(:everyday_trust, :test_http, fn _, _ ->
      Process.sleep(5000)
      {:error, :timeout}
    end)

    result = Analysis.run("https://bcp-acceso.com")
    assert result["verdict"] == "suspicious"
    assert Enum.any?(result["signals"], &(&1["id"] == "brand_lookalike"))
    assert result["coverage"]["registration"] == "partial"
  end

  test "RDAP uses IANA registry endpoint without user URL path" do
    parent = self()

    Application.put_env(:everyday_trust, :test_http, fn method, url ->
      send(parent, {:request, method, url})

      {:ok,
       %{
         status: 200,
         body: %{
           "events" => [
             %{
               "eventAction" => "registration",
               "eventDate" => DateTime.to_iso8601(DateTime.add(DateTime.utc_now(), -86400))
             }
           ]
         }
       }}
    end)

    result = Signals.url("https://synthetic.com/private?code=4821", true)
    assert result["age_status"] == "match"
    assert_received {:request, :get, "https://rdap.verisign.com/com/v1/domain/synthetic.com"}
    refute_received {:request, _, "https://synthetic.com/private?code=4821"}
    assert Enum.any?(result["signals"], &(&1["id"] == "new_domain"))
  end

  test "four digit codes are removed before model interpretation" do
    minimized =
      Analysis.minimize(
        "Tu código es 4821. Mi DNI 12345678 y mi enlace https://example.com/secret"
      )

    refute minimized =~ "4821"
    refute minimized =~ "12345678"
    refute minimized =~ "secret"
  end

  test "unknown model pattern is normalized without losing valid risk elevation" do
    result =
      Analysis.run("Hola")
      |> Interpreter.apply_output(%{
        "suggested_verdict" => "high_risk",
        "scam_type" => "invented_type",
        "cited_signal_ids" => []
      })

    assert result["scam_type"] == "undetermined"
    assert result["verdict"] == "suspicious"
    assert result["coverage"]["ai"] == "completed"
  end

  test "IP recognition handles brackets and rejects ordinary or oversized hostnames" do
    assert Signals.ip?("192.0.2.1")
    assert Signals.ip?("[2001:db8::1]")
    refute Signals.ip?("synthetic.example")
    refute Signals.ip?(String.duplicate("9", 253))
  end
end
