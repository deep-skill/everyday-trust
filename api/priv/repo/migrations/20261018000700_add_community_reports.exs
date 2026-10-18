defmodule EverydayTrust.Repo.Migrations.AddCommunityReports do
  use Ecto.Migration

  def change do
    create table(:community_reports, primary_key: false) do
      add :domain, :text, primary_key: true
      add :session_hash, :text, primary_key: true
      add :brand, :text
      add :verdict, :text, null: false
      add :reported_at, :utc_datetime_usec, null: false
    end

    create index(:community_reports, [:reported_at])
    create constraint(:community_reports, :community_session_hash_length, check: "char_length(session_hash) = 64")
    create constraint(:community_reports, :community_domain_length, check: "char_length(domain) BETWEEN 3 AND 253")
    create constraint(:community_reports, :community_verdict, check: "verdict IN ('suspicious', 'high_risk')")
  end
end
