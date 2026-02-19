defmodule SelectoTest.FilterSets.FilterSet do
  @moduledoc """
  Schema for saved filter sets.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "filter_sets" do
    field :name, :string
    field :description, :string
    field :domain, :string
    field :filters, :map
    field :user_id, :string
    field :is_default, :boolean, default: false
    field :is_shared, :boolean, default: false
    field :is_system, :boolean, default: false
    field :usage_count, :integer, default: 0

    timestamps()
  end

  @doc false
  def changeset(filter_set, attrs) do
    filter_set
    |> cast(attrs, [
      :name,
      :description,
      :domain,
      :filters,
      :user_id,
      :is_default,
      :is_shared,
      :is_system,
      :usage_count
    ])
    |> validate_required([:name, :domain, :filters, :user_id])
    |> validate_length(:name, min: 1, max: 100)
    |> validate_length(:description, max: 500)
  end
end
