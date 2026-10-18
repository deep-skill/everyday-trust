defmodule EverydayTrust.Repo.Migrations.CreateCases do
  use Ecto.Migration

  def change do
    create table(:account_profiles, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :issuer, :text, null: false
      add :subject, :text, null: false
      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:account_profiles, [:issuer, :subject])

    create table(:temporary_cases, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :session_hash, :text, null: false
      add :owner_id, references(:account_profiles, type: :uuid, on_delete: :delete_all)
      add :result, :map, null: false
      add :context, :text, null: false
      add :turns, :integer, default: 0, null: false
      add :feedback, :text
      add :expires_at, :utc_datetime_usec, null: false
      add :max_expires_at, :utc_datetime_usec, null: false
      timestamps(type: :utc_datetime_usec)
    end

    create index(:temporary_cases, [:expires_at])

    create table(:saved_cases, primary_key: false) do
      add :id, :uuid, primary_key: true

      add :owner_id, references(:account_profiles, type: :uuid, on_delete: :delete_all),
        null: false

      add :temporary_case_id, :uuid, null: false
      add :result, :map, null: false
      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:saved_cases, [:owner_id, :temporary_case_id])
    create index(:saved_cases, [:owner_id, :inserted_at, :id])

    create table(:quota_buckets, primary_key: false) do
      add :key, :text, primary_key: true
      add :count, :integer, null: false
      add :expires_at, :utc_datetime_usec, null: false
    end

    create index(:quota_buckets, [:expires_at])
  end
end
