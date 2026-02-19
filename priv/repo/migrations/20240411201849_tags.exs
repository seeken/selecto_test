defmodule SelectoTest.Repo.Migrations.Tags do
  use Ecto.Migration

  def change do
    create table(:tag) do
      add :name, :string

      timestamps()
    end

    create table(:film_tag) do
      add :film_id, references(:film, on_delete: :delete_all, column: :film_id)
      add :tag_id, references(:tag, on_delete: :delete_all)

      timestamps()
    end

    create(
      unique_index(
        :tag,
        ~w(name)a,
        name: :index_for_tag_name
      )
    )
  end
end
