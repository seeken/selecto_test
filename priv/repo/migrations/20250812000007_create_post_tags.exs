defmodule SelectoTest.Repo.Migrations.CreatePostTags do
  use Ecto.Migration

  def change do
    create table(:post_tags, primary_key: false) do
      add :post_id, references(:posts, on_delete: :delete_all), primary_key: true
      add :blog_tag_id, references(:blog_tags, on_delete: :delete_all), primary_key: true
      add :created_at, :utc_datetime, default: fragment("NOW()"), null: false
    end

    create index(:post_tags, [:post_id])
    create index(:post_tags, [:blog_tag_id])
  end
end
