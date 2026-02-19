defmodule SelectoTest.Repo.Migrations.CreateCategories do
  use Ecto.Migration

  def change do
    create table(:categories) do
      add :name, :string, null: false
      add :slug, :string, null: false
      add :description, :text
      add :color, :string
      add :active, :boolean, default: true
      add :post_count, :integer, default: 0
      add :parent_id, references(:categories, on_delete: :delete_all)

      timestamps(type: :utc_datetime)
    end

    create unique_index(:categories, [:slug])
    create index(:categories, [:parent_id])
    create index(:categories, [:active])
  end
end
