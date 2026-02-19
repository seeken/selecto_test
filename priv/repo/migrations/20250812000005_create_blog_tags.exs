defmodule SelectoTest.Repo.Migrations.CreateBlogTags do
  use Ecto.Migration

  def change do
    create table(:blog_tags) do
      add :name, :string, null: false
      add :slug, :string, null: false
      add :description, :text
      add :color, :string
      add :post_count, :integer, default: 0
      add :featured, :boolean, default: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:blog_tags, [:slug])
    create index(:blog_tags, [:featured])
  end
end
