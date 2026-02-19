defmodule SelectoTest.Store.Flag do
  use Ecto.Schema

  schema "flag" do
    field :name, :string

    timestamps()
  end
end
