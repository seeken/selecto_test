defmodule SelectoTest.Ecommerce.User do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "users" do
    field :email, :string
    field :username, :string
    field :first_name, :string
    field :last_name, :string
    field :phone, :string
    field :status, Ecto.Enum, values: [:active, :inactive, :suspended, :deleted]
    field :role, Ecto.Enum, values: [:customer, :admin, :vendor, :support]
    # JSON in MySQL/SQLite
    field :preferences, :map
    # JSON array in MySQL/SQLite
    field :tags, {:array, :string}
    field :metadata, :map

    # Hierarchical - users can refer other users
    belongs_to :referred_by, __MODULE__, foreign_key: :referrer_id
    has_many :referrals, __MODULE__, foreign_key: :referrer_id

    # Relationships
    # TODO: Uncomment when schemas are created
    # has_many :addresses, SelectoTest.Ecommerce.Address
    has_many :orders, SelectoTest.Ecommerce.Order
    # has_many :reviews, SelectoTest.Ecommerce.Review
    # has_many :cart_items, SelectoTest.Ecommerce.CartItem
    # has_many :wishlists, SelectoTest.Ecommerce.Wishlist

    # Many-to-many through junction
    many_to_many :groups, SelectoTest.Ecommerce.Group,
      join_through: SelectoTest.Ecommerce.UserGroup

    # Audit/dimension table relationship
    # TODO: Fix UserHistory schema to have user_id field
    # has_many :user_history, SelectoTest.Ecommerce.UserHistory

    timestamps()
  end

  @doc false
  def changeset(user, attrs) do
    user
    |> cast(attrs, [
      :email,
      :username,
      :first_name,
      :last_name,
      :phone,
      :status,
      :role,
      :preferences,
      :tags,
      :metadata,
      :referrer_id
    ])
    |> validate_required([:email, :username, :status, :role])
    |> unique_constraint(:email)
    |> unique_constraint(:username)
  end
end
