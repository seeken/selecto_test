defmodule SelectoTest.Blog.Author do
  @moduledoc """
  Blog author schema with posts relationship.

  Demonstrates various Ecto features for SelectoMix testing:
  - Basic field types (string, text, boolean, integer)
  - Timestamps
  - Unique constraints
  - Has many associations
  - Enum fields
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "authors" do
    field :name, :string
    field :email, :string
    field :bio, :string
    field :avatar_url, :string
    field :active, :boolean, default: true
    field :role, Ecto.Enum, values: [:author, :editor, :admin], default: :author
    field :follower_count, :integer, default: 0
    field :verified, :boolean, default: false

    has_many :posts, SelectoTest.Blog.Post
    has_many :comments, SelectoTest.Blog.Comment

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(author, attrs) do
    author
    |> cast(attrs, [:name, :email, :bio, :avatar_url, :active, :role, :follower_count, :verified])
    |> validate_required([:name, :email])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
    |> validate_inclusion(:role, [:author, :editor, :admin])
    |> validate_number(:follower_count, greater_than_or_equal_to: 0)
    |> unique_constraint(:email)
  end
end
