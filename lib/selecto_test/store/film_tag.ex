defmodule SelectoTest.Store.FilmTag do
  use Ecto.Schema

  @primary_key false

  schema "film_tag" do
    # has_one tag
    belongs_to :tag, SelectoTest.Store.Tag, primary_key: true
    # has_one film
    belongs_to :film, SelectoTest.Store.Film, primary_key: true, references: :film_id
    timestamps()
  end
end
