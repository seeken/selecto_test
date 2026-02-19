defmodule SelectoTest.Ecommerce.Group do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "groups" do
    field :name, :string
    field :description, :string
    field :type, Ecto.Enum, values: [:customer_segment, :loyalty_tier, :wholesale, :vip]
    field :permissions, {:array, :string}
    field :discount_percentage, :decimal
    field :priority, :integer

    many_to_many :users, SelectoTest.Ecommerce.User, join_through: SelectoTest.Ecommerce.UserGroup

    timestamps()
  end

  @doc false
  def changeset(group, attrs) do
    group
    |> cast(attrs, [:name, :description, :type, :permissions, :discount_percentage, :priority])
    |> validate_required([:name, :type])
    |> unique_constraint(:name)
  end
end
