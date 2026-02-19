defmodule SelectoTest.Blog.Category do
  @moduledoc """
  Blog category schema with hierarchical structure.

  Demonstrates:
  - Self-referencing associations
  - Many-to-many through join table
  - Counter cache pattern
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "categories" do
    field :name, :string
    field :slug, :string
    field :description, :string
    field :color, :string
    field :active, :boolean, default: true
    field :post_count, :integer, default: 0

    belongs_to :parent, __MODULE__
    has_many :children, __MODULE__, foreign_key: :parent_id

    many_to_many :posts, SelectoTest.Blog.Post,
      join_through: "post_categories",
      join_keys: [category_id: :id, post_id: :id]

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(category, attrs) do
    category
    |> cast(attrs, [:name, :slug, :description, :color, :active, :post_count, :parent_id])
    |> validate_required([:name, :slug])
    |> validate_format(:slug, ~r/^[a-z0-9\-_]+$/,
      message: "must be lowercase letters, numbers, dashes, and underscores only"
    )
    |> validate_format(:color, ~r/^#[0-9a-fA-F]{6}$/, message: "must be a valid hex color")
    |> validate_number(:post_count, greater_than_or_equal_to: 0)
    |> unique_constraint(:slug)
  end
end
