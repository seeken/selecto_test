defmodule SelectoTest.Repo.Migrations.CreateAuthors do
  use Ecto.Migration

  def change do
    create table(:authors) do
      add :name, :string, null: false
      add :email, :string, null: false
      add :bio, :text
      add :avatar_url, :string
      add :active, :boolean, default: true, null: false
      add :role, :string, default: "author"
      add :follower_count, :integer, default: 0
      add :verified, :boolean, default: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:authors, [:email])
    create index(:authors, [:active])
    create index(:authors, [:role])
  end
end
