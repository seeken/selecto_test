defmodule SelectoTest.Repo.Migrations.CreateComments do
  use Ecto.Migration

  def change do
    create table(:comments) do
      add :content, :text, null: false
      add :author_name, :string
      add :author_email, :string
      add :status, :string, default: "pending", null: false
      add :like_count, :integer, default: 0
      add :reply_count, :integer, default: 0
      add :post_id, references(:posts, on_delete: :delete_all), null: false
      add :parent_id, references(:comments, on_delete: :delete_all)
      add :author_id, references(:authors, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create index(:comments, [:post_id])
    create index(:comments, [:parent_id])
    create index(:comments, [:author_id])
    create index(:comments, [:status])
  end
end
