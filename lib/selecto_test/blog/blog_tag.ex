defmodule SelectoTest.Blog.BlogTag do
  @moduledoc """
  Blog tag schema for organizing posts.

  Demonstrates:
  - Many-to-many associations
  - Counter cache fields
  - Boolean flags
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "blog_tags" do
    field :name, :string
    field :slug, :string
    field :description, :string
    field :color, :string
    field :post_count, :integer, default: 0
    field :featured, :boolean, default: false

    many_to_many :posts, SelectoTest.Blog.Post,
      join_through: "post_tags",
      join_keys: [blog_tag_id: :id, post_id: :id]

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(blog_tag, attrs) do
    blog_tag
    |> cast(attrs, [:name, :slug, :description, :color, :post_count, :featured])
    |> validate_required([:name, :slug])
    |> validate_format(:slug, ~r/^[a-z0-9\-_]+$/,
      message: "must be lowercase letters, numbers, dashes, and underscores only"
    )
    |> validate_format(:color, ~r/^#[0-9a-fA-F]{6}$/, message: "must be a valid hex color")
    |> validate_number(:post_count, greater_than_or_equal_to: 0)
    |> unique_constraint(:slug)
  end
end
