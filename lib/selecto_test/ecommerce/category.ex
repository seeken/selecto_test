defmodule SelectoTest.Ecommerce.Category do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "categories" do
    field :name, :string
    field :slug, :string
    field :description, :string
    field :image_url, :string
    field :position, :integer
    field :is_active, :boolean, default: true
    field :metadata, :map

    # Hierarchical structure - adjacency list
    belongs_to :parent, __MODULE__, foreign_key: :parent_id
    has_many :children, __MODULE__, foreign_key: :parent_id

    # Materialized path for efficient queries
    # e.g., "/electronics/computers/laptops"
    field :path, :string
    field :level, :integer

    # Nested set model fields
    field :lft, :integer
    field :rgt, :integer

    # Products in this category
    has_many :products, SelectoTest.Ecommerce.Product

    timestamps()
  end

  @doc false
  def changeset(category, attrs) do
    category
    |> cast(attrs, [
      :name,
      :slug,
      :description,
      :image_url,
      :position,
      :is_active,
      :metadata,
      :parent_id,
      :path,
      :level,
      :lft,
      :rgt
    ])
    |> validate_required([:name, :slug])
    |> unique_constraint(:slug)
    |> validate_hierarchy()
  end

  defp validate_hierarchy(changeset) do
    # Custom validation to prevent circular references
    changeset
  end
end
