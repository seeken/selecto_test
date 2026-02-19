defmodule SelectoTest.Blog.Post do
  @moduledoc """
  Blog post schema with rich relationships.

  Demonstrates:
  - Multiple association types
  - Enum fields
  - Nullable fields
  - Counter cache fields
  - DateTime handling
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "posts" do
    field :title, :string
    field :slug, :string
    field :content, :string
    field :excerpt, :string
    field :status, Ecto.Enum, values: [:draft, :published, :archived], default: :draft
    field :published_at, :utc_datetime
    field :featured, :boolean, default: false
    field :view_count, :integer, default: 0
    field :like_count, :integer, default: 0
    field :comment_count, :integer, default: 0
    field :reading_time_minutes, :integer

    belongs_to :author, SelectoTest.Blog.Author
    has_many :comments, SelectoTest.Blog.Comment

    many_to_many :categories, SelectoTest.Blog.Category,
      join_through: "post_categories",
      join_keys: [post_id: :id, category_id: :id]

    many_to_many :blog_tags, SelectoTest.Blog.BlogTag,
      join_through: "post_tags",
      join_keys: [post_id: :id, blog_tag_id: :id]

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(post, attrs) do
    post
    |> cast(attrs, [
      :title,
      :slug,
      :content,
      :excerpt,
      :status,
      :published_at,
      :featured,
      :view_count,
      :like_count,
      :comment_count,
      :reading_time_minutes,
      :author_id
    ])
    |> validate_required([:title, :slug, :content])
    |> validate_format(:slug, ~r/^[a-z0-9\-_]+$/,
      message: "must be lowercase letters, numbers, dashes, and underscores only"
    )
    |> validate_inclusion(:status, [:draft, :published, :archived])
    |> validate_number(:view_count, greater_than_or_equal_to: 0)
    |> validate_number(:like_count, greater_than_or_equal_to: 0)
    |> validate_number(:comment_count, greater_than_or_equal_to: 0)
    |> validate_number(:reading_time_minutes, greater_than: 0)
    |> unique_constraint(:slug)
    |> maybe_set_published_at()
  end

  defp maybe_set_published_at(%{changes: %{status: :published}} = changeset) do
    case get_field(changeset, :published_at) do
      nil -> put_change(changeset, :published_at, DateTime.utc_now())
      _ -> changeset
    end
  end

  defp maybe_set_published_at(changeset), do: changeset
end
