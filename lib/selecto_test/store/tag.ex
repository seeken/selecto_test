defmodule SelectoTest.Store.Tag do
  use Ecto.Schema

  schema "tag" do
    field :name, :string

    timestamps()
  end
end
