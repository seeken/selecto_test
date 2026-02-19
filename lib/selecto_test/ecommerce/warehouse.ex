defmodule SelectoTest.Ecommerce.Warehouse do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "warehouses" do
    field :code, :string
    field :name, :string
    field :type, Ecto.Enum, values: [:fulfillment, :distribution, :cross_dock, :cold_storage]
    field :status, Ecto.Enum, values: [:active, :inactive, :maintenance]
    field :capacity, :integer
    field :current_stock, :integer
    # {lat, lng, address}
    field :location, :map
    field :operating_hours, :map
    # ["refrigeration", "hazmat", "bulk"]
    field :capabilities, {:array, :string}

    # Hierarchical - regional distribution
    belongs_to :parent_warehouse, __MODULE__, foreign_key: :parent_id
    has_many :child_warehouses, __MODULE__, foreign_key: :parent_id

    # Relationships
    # TODO: Uncomment when schemas are created
    # has_many :inventory_items, SelectoTest.Ecommerce.InventoryItem
    # has_many :transfers_from, SelectoTest.Ecommerce.Transfer, foreign_key: :from_warehouse_id
    # has_many :transfers_to, SelectoTest.Ecommerce.Transfer, foreign_key: :to_warehouse_id
    # has_many :shipments, SelectoTest.Ecommerce.Shipment

    # Many-to-many zone coverage
    # TODO: Uncomment when schemas are created
    # many_to_many :delivery_zones, SelectoTest.Ecommerce.DeliveryZone,
    #   join_through: SelectoTest.Ecommerce.WarehouseZone

    timestamps()
  end

  @doc false
  def changeset(warehouse, attrs) do
    warehouse
    |> cast(attrs, [
      :code,
      :name,
      :type,
      :status,
      :capacity,
      :current_stock,
      :location,
      :operating_hours,
      :capabilities,
      :parent_id
    ])
    |> validate_required([:code, :name, :type, :status])
    |> unique_constraint(:code)
    |> validate_number(:capacity, greater_than: 0)
    |> validate_number(:current_stock, greater_than_or_equal_to: 0)
  end
end
