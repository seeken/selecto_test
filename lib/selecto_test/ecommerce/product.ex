defmodule SelectoTest.Ecommerce.Product do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "products" do
    field :sku, :string
    field :name, :string
    field :description, :string
    field :price, :decimal
    field :cost, :decimal
    field :weight, :decimal
    # {length, width, height}
    field :dimensions, :map
    field :status, Ecto.Enum, values: [:active, :inactive, :discontinued, :draft]
    field :type, Ecto.Enum, values: [:physical, :digital, :service, :bundle]
    field :tags, {:array, :string}
    # Flexible product attributes
    field :attributes, :map
    # For full-text search
    field :search_vector, :string

    # Hierarchical category relationship
    belongs_to :category, SelectoTest.Ecommerce.Category
    # TODO: Uncomment when schemas are created
    # belongs_to :brand, SelectoTest.Ecommerce.Brand
    # belongs_to :vendor, SelectoTest.Ecommerce.Vendor

    # Relationships
    # TODO: Uncomment when schemas are created
    # has_many :variants, SelectoTest.Ecommerce.ProductVariant
    # has_many :inventory_items, SelectoTest.Ecommerce.InventoryItem
    # has_many :reviews, SelectoTest.Ecommerce.Review
    # has_many :order_items, SelectoTest.Ecommerce.OrderItem
    # has_many :cart_items, SelectoTest.Ecommerce.CartItem

    # Many-to-many relationships
    # TODO: Uncomment when schemas are created
    # many_to_many :related_products, __MODULE__,
    #   join_through: SelectoTest.Ecommerce.ProductRelation

    # many_to_many :collections, SelectoTest.Ecommerce.Collection,
    #   join_through: SelectoTest.Ecommerce.ProductCollection

    # Slowly changing dimension
    # TODO: Uncomment when schema is created
    # has_many :product_history, SelectoTest.Ecommerce.ProductHistory

    timestamps()
  end

  @doc false
  def changeset(product, attrs) do
    product
    |> cast(attrs, [
      :sku,
      :name,
      :description,
      :price,
      :cost,
      :weight,
      :dimensions,
      :status,
      :type,
      :tags,
      :attributes,
      # brand_id, vendor_id removed until schemas exist
      :category_id
    ])
    |> validate_required([:sku, :name, :price, :status, :type])
    |> unique_constraint(:sku)
    |> validate_number(:price, greater_than: 0)
  end
end
