defmodule EverydayTrust.Repo.Migrations.AddReviews do
  use Ecto.Migration

  def change do
    create table(:reviews, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :case_id, :uuid, null: false
      add :owner_id, references(:account_profiles, type: :uuid, on_delete: :delete_all)
      add :kind, :text, null: false
      add :rating, :integer, null: false
      add :comment, :text, null: false, default: ""
      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:reviews, [:case_id])
    create index(:reviews, [:owner_id])
    create index(:reviews, [:inserted_at])
    create constraint(:reviews, :rating_range, check: "rating BETWEEN 1 AND 5")
    create constraint(:reviews, :comment_length, check: "char_length(comment) <= 500")
  end
end
