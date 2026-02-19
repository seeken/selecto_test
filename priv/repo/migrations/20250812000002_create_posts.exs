defmodule SelectoTest.Repo.Migrations.CreatePosts do
  use Ecto.Migration

  def change do
    create table(:posts) do
      add :title, :string, null: false
      add :slug, :string, null: false
      add :content, :text, null: false
      add :excerpt, :string
      add :status, :string, default: "draft", null: false
      add :published_at, :utc_datetime
      add :featured, :boolean, default: false
      add :view_count, :integer, default: 0
      add :like_count, :integer, default: 0
      add :comment_count, :integer, default: 0
      add :reading_time_minutes, :integer
      add :author_id, references(:authors, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create unique_index(:posts, [:slug])
    create index(:posts, [:author_id])
    create index(:posts, [:status])
    create index(:posts, [:published_at])
    create index(:posts, [:featured])
  end
end
