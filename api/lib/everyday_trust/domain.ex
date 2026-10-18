defmodule EverydayTrust.Domain do
  def public_suffix(host) when host in [nil, ""], do: nil
  def public_suffix(host), do: PublicSufx.public_suffix(host)
  def matches_explicit_rule?(host) when host in [nil, ""], do: false
  def matches_explicit_rule?(host), do: PublicSufx.prevailing_rule(host) != "*"

  def registrable_domain(host) do
    suffix = public_suffix(host)

    if suffix do
      parts = String.split(host, ".")
      count = length(String.split(suffix, ".")) + 1
      if length(parts) >= count, do: parts |> Enum.take(-count) |> Enum.join(".")
    end
  end
end
