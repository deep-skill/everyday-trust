defmodule EverydayTrust.Signals do
  @external_resource Path.expand("../../priv/catalog/brands.json", __DIR__)
  @external_resource Path.expand("../../priv/catalog/text_rules.json", __DIR__)
  @catalog Jason.decode!(File.read!(Path.expand("../../priv/catalog/brands.json", __DIR__)))
  @rules Jason.decode!(File.read!(Path.expand("../../priv/catalog/text_rules.json", __DIR__)))
  @rdap_path Path.expand("../../priv/catalog/rdap-bootstrap.json", __DIR__)
  @external_resource @rdap_path
  @rdap_routes Jason.decode!(File.read!(@rdap_path))["services"]
               |> Enum.flat_map(fn [tlds, urls] ->
                 base = Enum.find(urls, &String.starts_with?(&1, "https://"))
                 if base, do: Enum.map(tlds, &{&1, base}), else: []
               end)
               |> Map.new()
  @url ~r/(?<![\p{L}\p{N}_@\/.\\-])(?:https?:\/\/[^\s<>"'`“”‘’]+|(?:(?:[\p{L}\p{N}-]+\.)+(?:[\p{L}]{2,}|xn--[a-z0-9-]+)|(?:\d{1,3}\.){3}\d{1,3}|\[[a-f0-9:]+\])[^\s<>"'`“”‘’]*)/iu
  @credential ~r/\b(?:(no|nunca|jam[aá]s)\s+(?:(?:debes|deber[ií]as)\s+)?)?(?:compart(?:[ea]s?|ir)|env[ií](?:[ea]s?|ar)(?:me|nos)?|entreg(?:[au]es?|a|ar)|revel(?:[ea]s?|ar)|ingres(?:[ea]s?|ar)|proporcion(?:[ea]s?|ar)|confirm(?:[ea]s?|ar)|valid(?:[ea]s?|ar)|dime|dame|p[aá]same)\b/iu
  @denial ~r/\b(?:(?:ning[uú]n banco|ninguna empresa)\s+(?:te\s+)?(?:pide|pedir[aá]|solicita)|(?:no|nunca|jam[aá]s)\s+(?:te\s+)?(?:pedimos|pediremos|solicitamos|solicitaremos))(?!\p{L})/iu
  @reference ~r/^(?:[\s,]+|(?:tu|su|tus|sus|la|el|las|los|este|ese|claves?|contrase[ñn]as?|tokens?|c[oó]digos?|de|verificaci[oó]n|seguridad|sms|cvv|pin|ni|o|y|a|con|nadie)\b)*$/iu

  def extract_urls(text) do
    Regex.scan(@url, text)
    |> List.flatten()
    |> Enum.map(&trim_url/1)
    |> Enum.filter(fn raw ->
      uri = parse(raw)

      String.match?(raw, ~r/^https?:\/\//i) or
        (uri &&
           (ip?(uri.host) or String.contains?(raw, "@") or
              EverydayTrust.Domain.matches_explicit_rule?(uri.host)))
    end)
    |> Enum.uniq()
  end

  defp trim_url(raw) do
    raw = String.replace(raw, ~r/[.,;:!?…]+$/, "")

    Enum.reduce([{"(", ")"}, {"[", "]"}, {"{", "}"}], raw, fn {a, b}, value ->
      balance(value, a, b)
    end)
  end

  defp balance(value, a, b) do
    if String.ends_with?(value, b) &&
         length(String.split(value, b)) > length(String.split(value, a)),
       do: balance(String.slice(value, 0..-2//1), a, b),
       else: value
  end

  def parse(raw) do
    uri = URI.parse(if String.match?(raw, ~r/^https?:\/\//i), do: raw, else: "https://" <> raw)

    with true <- uri.scheme in ["http", "https"],
         host when is_binary(host) <- uri.host,
         false <- String.contains?(host, ["%", "\\", " "]),
         host <- host |> String.trim_trailing(".") |> String.downcase(),
         host <-
           if(ip?(host),
             do: host,
             else: host |> String.to_charlist() |> :idna.encode() |> to_string()
           ),
         true <- host != "" do
      %{uri | host: host}
    else
      _ -> nil
    end
  rescue
    _ -> nil
  end

  def ip?(nil), do: false

  def ip?(host) do
    host = host |> String.trim_leading("[") |> String.trim_trailing("]")

    byte_size(host) <= 45 && (String.contains?(host, ":") || Regex.match?(~r/^[0-9.]+$/, host)) &&
      match?({:ok, _}, :inet.parse_address(String.to_charlist(host)))
  end

  def signal(id, severity, message),
    do: %{"id" => id, "severity" => severity, "message" => message}

  def text(text) do
    Enum.flat_map(@rules, fn rule ->
      pattern = Regex.compile!(rule["pattern"], "iu")
      matches = Regex.scan(pattern, text, return: :index) |> Enum.map(&hd/1)

      if Enum.any?(matches, fn {offset, len} -> not safety?(rule["id"], text, offset, len) end),
        do: [Map.take(rule, ["id", "severity", "message"])],
        else: []
    end)
  end

  defp safety?("asks_credentials", text, offset, _) do
    before = binary_part(text, 0, offset) |> String.split(~r/[.!?;\n]/) |> List.last()
    request = Regex.scan(@credential, before, return: :index) |> List.last()
    denial = Regex.scan(@denial, before, return: :index) |> List.last()
    instruction = request || denial

    case instruction do
      [{start, len} | captures] ->
        negative = is_nil(request) || Enum.any?(captures, fn {_, l} -> l > 0 end)

        negative &&
          Regex.match?(
            @reference,
            binary_part(before, start + len, byte_size(before) - start - len)
          )

      _ ->
        false
    end
  end

  defp safety?("prize_or_refund", text, offset, len) do
    before = binary_part(text, 0, offset) |> String.split(~r/[.!?;\n]/) |> List.last()

    after_text =
      binary_part(text, offset + len, byte_size(text) - offset - len)
      |> String.split(~r/[.!?;\n]/)
      |> hd()

    Regex.match?(~r/\bsi\b[^.!?;\n]{0,100}$/iu, before) &&
      Regex.match?(
        ~r/\b(?:no|nunca|jam[aá]s)\s+(?:respondas?|pagues?|deposites?|hagas (?:clic|click)|abras?|ingreses?|env[ií]es?|compartas?|creas?)\b/iu,
        after_text
      )
  end

  defp safety?(_, _, _, _), do: false

  def phones(text) do
    Regex.scan(~r/(?:\+|00)?\d[\d\s-]{7,16}\d/, text)
    |> List.flatten()
    |> Enum.flat_map(fn raw ->
      digits = raw |> String.replace(~r/\D/, "") |> String.replace(~r/^00/, "")

      if String.length(digits) < 9 do
        []
      else
        foreign =
          String.match?(raw, ~r/^(\+|00)/) &&
            !(String.starts_with?(digits, "51") && String.length(digits) >= 10)

        if foreign,
          do: [
            signal(
              "foreign_number",
              "medium",
              "El mensaje incluye un número extranjero. Esto no identifica a su titular ni demuestra fraude."
            )
          ],
          else: []
      end
    end)
  end

  def url(input, network \\ true) do
    initial = parse(input)
    short = initial && shortener?(initial)

    {final, resolved, redirect_hosts} =
      if short && network, do: resolve(initial, [], 0), else: {initial, !short, []}

    host = if final, do: final.host, else: ""
    domain = if ip?(host), do: nil, else: EverydayTrust.Domain.registrable_domain(host)
    suffix = EverydayTrust.Domain.public_suffix(host)
    official = Enum.find(@catalog["brands"], &(domain in &1["domains"]))
    government = String.ends_with?(host, ".gob.pe")
    imitated = if !official && !government, do: imitation(host, domain, suffix)

    signals =
      []
      |> add(short, "shortener", "low", "El enlace usa un acortador que oculta su destino.")
      |> add(
        short && !resolved,
        "unresolved_shortener",
        "medium",
        "No pudimos verificar el destino del acortador."
      )
      |> add(
        is_nil(final),
        "invalid_url",
        "medium",
        "El enlace tiene un formato que no pudimos verificar."
      )
      |> add(
        (initial && initial.userinfo) || (final && final.userinfo),
        "url_userinfo",
        "high",
        "El enlace usa texto antes de @ que puede ocultar el destino real."
      )
      |> add(
        ip?(host),
        "ip_address",
        "medium",
        "El enlace apunta a una dirección IP. Confirma su origen."
      )
      |> add(
        imitated,
        "brand_lookalike",
        "high",
        if(imitated,
          do: "El enlace menciona a #{imitated["name"]}, pero no pertenece a su dominio oficial.",
          else: ""
        )
      )
      |> add(
        String.contains?(host, "xn--"),
        "punycode",
        "high",
        "El dominio contiene caracteres internacionales que pueden confundirse con otras letras."
      )
      |> add(
        suffix in @catalog["suspicious_tlds"],
        "suspicious_tld",
        "low",
        "La terminación del dominio merece una comprobación adicional."
      )
      |> add(final && final.scheme == "http", "no_https", "low", "El enlace no usa HTTPS.")

    {age, status} =
      if network && final && domain && !official && !government && !shortener?(final),
        do: age(domain),
        else: {nil, "not_applicable"}

    signals =
      signals
      |> add(
        is_integer(age) && age < 30,
        "new_domain",
        "high",
        "El dominio fue registrado hace menos de 30 días."
      )
      |> add(
        is_integer(age) && age >= 30 && age < 180,
        "recent_domain",
        "medium",
        "El dominio fue registrado hace menos de seis meses."
      )

    destination =
      if network && final && !shortener?(final),
        do: EverydayTrust.Destination.check(final),
        else: %{status: "not_checked", hosts: []}

    extra_hosts = destination.hosts |> Enum.reject(&(&1 == host)) |> Enum.uniq()
    extra_findings = Enum.map(extra_hosts, &url("https://" <> &1, false))
    changed = Enum.any?(extra_findings, &(&1["domain"] != domain))

    signals =
      (signals ++ Enum.flat_map(extra_findings, & &1["signals"]))
      |> add(
        changed,
        "destination_changed",
        "low",
        "El sitio redirige a una dirección de otra empresa o servicio."
      )

    %{
      "domain" => domain,
      "hostname" => host,
      "official_brand" =>
        if(official, do: official["name"], else: if(government, do: "Estado peruano (gob.pe)")),
      "signals" => signals,
      "destination_status" => destination.status,
      "checked_hosts" => Enum.uniq(redirect_hosts ++ [host | destination.hosts]),
      "age_status" => status,
      "redirect_status" =>
        if(short, do: if(resolved, do: "match", else: "unavailable"), else: "not_applicable")
    }
  rescue
    _ ->
      %{
        "hostname" => nil,
        "domain" => nil,
        "official_brand" => nil,
        "signals" => [
          signal("invalid_url", "medium", "No pudimos verificar el formato del enlace.")
        ],
        "age_status" => "unavailable",
        "redirect_status" => "unavailable"
      }
  end

  defp add(items, condition, id, severity, message),
    do: if(condition, do: items ++ [signal(id, severity, message)], else: items)

  defp shortener?(uri), do: String.replace_prefix(uri.host, "www.", "") in @catalog["shorteners"]

  defp resolve(uri, seen, hop) do
    cond do
      !shortener?(uri) ->
        resolved(uri, true, seen)

      hop >= 5 || uri.scheme != "https" || uri.port != 443 || uri.userinfo ||
          URI.to_string(uri) in seen ->
        resolved(uri, false, seen)

      true ->
        with {:ok, %{status: status, headers: headers}} <- http(:head, URI.to_string(uri)),
             true <- status in 300..399,
             [location | _] <- Map.get(headers, "location", []),
             target <- URI.merge(uri, location),
             true <- target.scheme in ["http", "https"],
             next when not is_nil(next) <- parse(URI.to_string(target)) do
          resolve(next, seen ++ [URI.to_string(uri)], hop + 1)
        else
          _ -> resolved(uri, false, seen)
        end
    end
  rescue
    _ -> resolved(uri, false, seen)
  end

  defp resolved(uri, complete, seen),
    do:
      {uri, complete, Enum.map(seen ++ [URI.to_string(uri)], &URI.parse(&1).host) |> Enum.uniq()}

  defp rdap_base(domain), do: Map.get(@rdap_routes, domain |> String.split(".") |> List.last())

  defp age(domain) do
    with true <- EverydayTrust.Domain.matches_explicit_rule?(domain),
         base when is_binary(base) <- rdap_base(domain),
         {:ok, %{status: 200, body: %{"events" => events}}} <-
           http(:get, base <> "domain/" <> domain),
         %{"eventDate" => date} <- Enum.find(events, &(&1["eventAction"] == "registration")),
         {:ok, created, _} <- DateTime.from_iso8601(date) do
      {max(0, div(DateTime.diff(DateTime.utc_now(), created), 86_400)), "match"}
    else
      _ -> {nil, "unavailable"}
    end
  rescue
    _ -> {nil, "unavailable"}
  end

  defp http(method, url) do
    case Application.get_env(:everyday_trust, :test_http) do
      fun when is_function(fun, 2) ->
        fun.(method, url)

      _ ->
        Req.request(
          method: method,
          url: url,
          redirect: false,
          retry: false,
          receive_timeout: 1_000,
          connect_options: [timeout: 1_000]
        )
    end
  end

  defp imitation(host, domain, suffix) do
    deleet = fn value ->
      String.replace(value, ~r/[013457]/, fn c ->
        %{"0" => "o", "1" => "l", "3" => "e", "4" => "a", "5" => "s", "7" => "t"}[c]
      end)
    end

    normalized = deleet.(host)
    compact = String.replace(normalized, ~r/[^a-z]/, "")
    tokens = String.split(normalized, ~r/[^a-z]+/, trim: true)
    label = deleet.(String.replace_suffix(domain || "", "." <> (suffix || ""), ""))

    Enum.find(@catalog["brands"], fn brand ->
      Enum.any?(brand["keywords"], fn word ->
        if String.length(word) >= 5,
          do: String.contains?(compact, word),
          else: Enum.any?(tokens, &(String.starts_with?(&1, word) || String.ends_with?(&1, word)))
      end) ||
        Enum.any?(brand["domains"], fn official ->
          base =
            String.replace_suffix(
              official,
              "." <> EverydayTrust.Domain.public_suffix(official),
              ""
            )

          String.length(base) >= 5 && base != label &&
            distance(base, label) <= if(String.length(base) >= 8, do: 2, else: 1)
        end)
    end)
  end

  defp distance(a, b) do
    Enum.reduce(
      Enum.with_index(String.graphemes(a), 1),
      Enum.to_list(0..String.length(b)),
      fn {ca, i}, previous ->
        {row, _} =
          Enum.reduce(Enum.with_index(String.graphemes(b), 1), {[i], i}, fn {cb, j},
                                                                            {row, left} ->
            value =
              Enum.min([
                left + 1,
                Enum.at(previous, j) + 1,
                Enum.at(previous, j - 1) + if(ca == cb, do: 0, else: 1)
              ])

            {row ++ [value], value}
          end)

        row
      end
    )
    |> List.last()
  end
end
