defmodule SelectoTest.Ecommerce.Order do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "orders" do
    field :order_number, :string

    field :status, Ecto.Enum,
      values: [
        :pending,
        :confirmed,
        :processing,
        :shipped,
        :delivered,
        :cancelled,
        :refunded
      ]

    field :payment_status, Ecto.Enum, values: [:pending, :paid, :failed, :refunded]

    field :fulfillment_status, Ecto.Enum,
      values: [
        :unfulfilled,
        :partial,
        :fulfilled,
        :returned
      ]

    field :subtotal, :decimal
    field :tax_amount, :decimal
    field :shipping_amount, :decimal
    field :discount_amount, :decimal
    field :total_amount, :decimal
    field :currency, :string, default: "USD"
    field :notes, :string
    field :metadata, :map

    # Relationships
    belongs_to :user, SelectoTest.Ecommerce.User
    # TODO: Uncomment when schemas are created
    # belongs_to :shipping_address, SelectoTest.Ecommerce.Address
    # belongs_to :billing_address, SelectoTest.Ecommerce.Address
    # belongs_to :coupon, SelectoTest.Ecommerce.Coupon

    # has_many :order_items, SelectoTest.Ecommerce.OrderItem
    # has_many :shipments, SelectoTest.Ecommerce.Shipment
    # has_many :payments, SelectoTest.Ecommerce.Payment
    # has_many :refunds, SelectoTest.Ecommerce.Refund
    # has_many :order_events, SelectoTest.Ecommerce.OrderEvent

    # Complex join - products through order items
    # TODO: Uncomment when OrderItem schema is created
    # has_many :products, through: [:order_items, :product]

    timestamps()
  end

  @doc false
  def changeset(order, attrs) do
    order
    |> cast(attrs, [
      :order_number,
      :status,
      :payment_status,
      :fulfillment_status,
      :subtotal,
      :tax_amount,
      :shipping_amount,
      :discount_amount,
      :total_amount,
      :currency,
      :notes,
      :metadata,
      # address and coupon IDs removed until schemas exist
      :user_id
    ])
    |> validate_required([:order_number, :status, :payment_status, :total_amount])
    |> unique_constraint(:order_number)
    |> validate_number(:total_amount, greater_than_or_equal_to: 0)
  end
end
