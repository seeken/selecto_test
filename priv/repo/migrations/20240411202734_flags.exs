defmodule SelectoTest.Repo.Migrations.Flags do
  use Ecto.Migration

  def change do
    create table(:flag) do
      add :name, :string

      timestamps()
    end

    create table(:film_flag) do
      add :film_id, references(:film, on_delete: :delete_all, column: :film_id)
      add :flag_id, references(:flag, on_delete: :delete_all)
      add :value, :string

      timestamps()
    end
  end
end
