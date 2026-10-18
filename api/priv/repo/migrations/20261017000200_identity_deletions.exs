defmodule EverydayTrust.Repo.Migrations.IdentityDeletions do
  use Ecto.Migration

  def change do
    create table(:identity_deletions, primary_key: false) do
      add :identity_hash, :text, primary_key: true
      add :status, :text, null: false
      add :expires_at, :utc_datetime_usec, null: false
    end
  end
end
