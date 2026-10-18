defmodule EverydayTrust.Repo.Migrations.FeedPublication do
  use Ecto.Migration

  def change do
    alter table(:threat_versions) do
      add :published_at, :utc_datetime_usec
    end
  end
end
