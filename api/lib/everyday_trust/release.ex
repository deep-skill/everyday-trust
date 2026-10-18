defmodule EverydayTrust.Release do
  def ingest(file, digest, fetched_at, published_at) do
    Application.load(:everyday_trust)

    Ecto.Migrator.with_repo(EverydayTrust.Repo, fn _ ->
      EverydayTrust.Threats.ingest(file, digest, fetched_at, published_at)
    end)
  end

  def migrate do
    Application.load(:everyday_trust)

    for repo <- Application.fetch_env!(:everyday_trust, :ecto_repos) do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end
end
