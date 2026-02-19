defmodule SelectoTest.Store.FilmFlag do
  use Ecto.Schema

  @primary_key false

  schema "film_flag" do
    # has_one flag
    belongs_to :flag, SelectoTest.Store.Flag, primary_key: true
    # has_one film
    belongs_to :film, SelectoTest.Store.Film, primary_key: true, references: :film_id

    field :value, :string
    timestamps()
  end
end
