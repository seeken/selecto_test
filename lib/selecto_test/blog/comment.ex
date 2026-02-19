defmodule SelectoTest.Blog.Comment do
  @moduledoc """
  Blog comment schema with hierarchical threading.

  Demonstrates:
  - Self-referencing associations for threading
  - Optional associations (author can be nil for guest comments)
  - Multiple parent relationships
  - Counter caches
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "comments" do
    field :content, :string
    field :author_name, :string
    field :author_email, :string
    field :status, Ecto.Enum, values: [:pending, :approved, :spam, :deleted], default: :pending
    field :like_count, :integer, default: 0
    field :reply_count, :integer, default: 0

    belongs_to :post, SelectoTest.Blog.Post
    belongs_to :parent, __MODULE__
    belongs_to :author, SelectoTest.Blog.Author

    has_many :replies, __MODULE__, foreign_key: :parent_id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(comment, attrs) do
    comment
    |> cast(attrs, [
      :content,
      :author_name,
      :author_email,
      :status,
      :like_count,
      :reply_count,
      :post_id,
      :parent_id,
      :author_id
    ])
    |> validate_required([:content, :post_id])
    |> validate_format(:author_email, ~r/^[^\s]+@[^\s]+$/,
      message: "must have the @ sign and no spaces"
    )
    |> validate_inclusion(:status, [:pending, :approved, :spam, :deleted])
    |> validate_number(:like_count, greater_than_or_equal_to: 0)
    |> validate_number(:reply_count, greater_than_or_equal_to: 0)
    |> validate_guest_or_registered_author()
  end

  defp validate_guest_or_registered_author(changeset) do
    author_id = get_field(changeset, :author_id)
    author_name = get_field(changeset, :author_name)
    author_email = get_field(changeset, :author_email)

    cond do
      # Registered user comment
      author_id ->
        changeset

      # Guest comment - require name and email
      author_name && author_email ->
        changeset

      # Invalid - missing required fields
      true ->
        changeset
        |> add_error(:author_name, "is required for guest comments")
        |> add_error(:author_email, "is required for guest comments")
    end
  end
end
