defmodule EverydayTrust.Repo.Migrations.ThreatFeed do
  use Ecto.Migration

  def change do
    create table(:threat_versions, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :digest, :text, null: false
      add :fetched_at, :utc_datetime_usec, null: false
      add :active, :boolean, null: false, default: false
      add :record_count, :integer, null: false
    end

    create unique_index(:threat_versions, [:active], where: "active = true")

    create table(:threat_indicators, primary_key: false) do
      add :version_id, references(:threat_versions, type: :uuid, on_delete: :delete_all),
        null: false

      add :host, :text, null: false
      add :status, :text, null: false
    end

    create unique_index(:threat_indicators, [:version_id, :host])
  end
end
