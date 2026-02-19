defmodule SelectoTest.Ecommerce.UserGroup do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "user_groups" do
    field :role, Ecto.Enum, values: [:member, :moderator, :admin]
    field :joined_at, :utc_datetime
    field :expires_at, :utc_datetime
    field :is_active, :boolean, default: true

    belongs_to :user, SelectoTest.Ecommerce.User
    belongs_to :group, SelectoTest.Ecommerce.Group

    timestamps()
  end

  @doc false
  def changeset(user_group, attrs) do
    user_group
    |> cast(attrs, [:role, :joined_at, :expires_at, :is_active, :user_id, :group_id])
    |> validate_required([:role, :user_id, :group_id])
    |> unique_constraint([:user_id, :group_id])
  end
end
