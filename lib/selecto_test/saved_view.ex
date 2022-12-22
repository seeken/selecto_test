defmodule SelectoTest.SavedView do
  use Ecto.Schema
  import Ecto.Changeset

  schema "saved_views" do
    field :context, :string
    field :name, :string
    field :params, :map

    timestamps()
  end

  @doc false
  def changeset(saved_view, attrs) do
    IO.inspect(saved_view)
    IO.inspect(attrs)
    saved_view
    |> cast(attrs, [:name, :context, :params])
    |> validate_required([:name, :context, :params])
    |> unique_constraint([:name, :context], name: :index_for_saved_view_name_context)
  end

end
