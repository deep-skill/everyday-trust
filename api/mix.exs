defmodule EverydayTrust.MixProject do
  use Mix.Project

  def project do
    [
      app: :everyday_trust,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: ["ecto.setup": ["ecto.create", "ecto.migrate"]]
    ]
  end

  def application,
    do: [mod: {EverydayTrust.Application, []}, extra_applications: [:logger, :crypto]]

  defp deps do
    [
      {:phoenix, "~> 1.8.0"},
      {:bandit, "~> 1.6"},
      {:ecto_sql, "~> 3.13"},
      {:postgrex, "~> 0.21"},
      {:jason, "~> 1.4"},
      {:req, "~> 0.5"},
      {:mint, "~> 1.11"},
      {:jose, "~> 1.11"},
      {:public_sufx, "0.7.20260908"},
      {:idna, "~> 7.1"}
    ]
  end
end
