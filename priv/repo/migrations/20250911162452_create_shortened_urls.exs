defmodule SelectoTest.Repo.Migrations.CreateShortenedUrls do
  use Ecto.Migration

  def change do
    create table(:shortened_urls, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :short_code, :string, null: false
      add :long_url, :text, null: false
      add :expires_at, :utc_datetime
      add :click_count, :integer, default: 0, null: false
      add :last_accessed_at, :utc_datetime
      add :metadata, :map, default: %{}
      add :creator_id, :binary_id
      add :is_public, :boolean, default: true, null: false

      timestamps()
    end

    create unique_index(:shortened_urls, [:short_code])
    create index(:shortened_urls, [:expires_at])
    create index(:shortened_urls, [:creator_id])
    create index(:shortened_urls, [:inserted_at])
  end
end
