defmodule EverydayTrust.Repo.Migrations.AddCompletionMetrics do
  use Ecto.Migration

  def change do
    alter table(:temporary_cases) do
      add :kind, :text, null: false, default: "query"
      add :analysis_pending, :boolean, null: false, default: false
      add :analysis_deadline, :utc_datetime_usec
    end

    create index(:temporary_cases, [:analysis_deadline], where: "analysis_pending")

    create table(:daily_metrics, primary_key: false) do
      add :day, :date, primary_key: true
      add :kind, :text, primary_key: true
      add :metric, :text, primary_key: true
      add :count, :bigint, null: false
    end
  end
end
