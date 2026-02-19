defmodule SelectoTest.Ecommerce.UserHistory do
  use Ecto.Schema
  import Ecto.Changeset

  @moduledoc """
  Slowly Changing Dimension Type 2 for User data.
  Tracks historical changes to user attributes over time.
  """

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "user_history" do
    # Natural key to user
    field :user_key, :binary_id
    field :email, :string
    field :username, :string
    field :first_name, :string
    field :last_name, :string
    field :phone, :string
    field :status, :string
    field :role, :string
    field :preferences, :map
    field :valid_from, :utc_datetime
    field :valid_to, :utc_datetime
    field :is_current, :boolean, default: false
    field :change_reason, :string
    field :version, :integer

    belongs_to :user, SelectoTest.Ecommerce.User,
      foreign_key: :user_key,
      references: :id,
      define_field: false
  end

  @doc false
  def changeset(user_history, attrs) do
    user_history
    |> cast(attrs, [
      :user_key,
      :email,
      :username,
      :first_name,
      :last_name,
      :phone,
      :status,
      :role,
      :preferences,
      :valid_from,
      :valid_to,
      :is_current,
      :change_reason,
      :version
    ])
    |> validate_required([:user_key, :email, :username, :valid_from, :version])
  end
end
