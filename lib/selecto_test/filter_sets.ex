defmodule SelectoTest.FilterSets do
  @moduledoc """
  Context for managing saved filter sets.
  """

  @behaviour SelectoComponents.FilterSetsBehaviour

  import Ecto.Query, warn: false
  alias SelectoTest.Repo
  alias SelectoTest.FilterSets.FilterSet

  @doc """
  Lists personal filter sets for a user and domain.
  """
  def list_personal_filter_sets(user_id, domain) do
    FilterSet
    |> where([f], f.user_id == ^user_id and f.domain == ^domain)
    |> where([f], f.is_shared == false and f.is_system == false)
    |> order_by([f], desc: f.is_default, asc: f.name)
    |> Repo.all()
  end

  @doc """
  Lists shared filter sets for a domain.
  """
  def list_shared_filter_sets(_user_id, domain) do
    FilterSet
    |> where([f], f.is_shared == true and f.domain == ^domain)
    |> order_by([f], asc: f.name)
    |> Repo.all()
  end

  @doc """
  Lists system filter sets for a domain.
  """
  def list_system_filter_sets(domain) do
    FilterSet
    |> where([f], f.is_system == true and f.domain == ^domain)
    |> order_by([f], asc: f.name)
    |> Repo.all()
  end

  @doc """
  Gets a single filter set.
  """
  def get_filter_set!(id), do: Repo.get!(FilterSet, id)

  def get_filter_set(id, _user_id) do
    case Repo.get(FilterSet, id) do
      nil -> {:error, :not_found}
      filter_set -> {:ok, filter_set}
    end
  end

  @doc """
  Creates a filter set.
  """
  def create_filter_set(attrs \\ %{}) do
    # If setting as default, unset other defaults for this user/domain
    attrs =
      if Map.get(attrs, :is_default) || Map.get(attrs, "is_default") do
        unset_defaults(attrs[:user_id] || attrs["user_id"], attrs[:domain] || attrs["domain"])
        attrs
      else
        attrs
      end

    %FilterSet{}
    |> FilterSet.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a filter set.
  """
  def update_filter_set(id, attrs, user_id) do
    with {:ok, filter_set} <- get_filter_set(id, user_id),
         true <- filter_set.user_id == user_id do
      # If setting as default, unset other defaults
      attrs =
        if Map.get(attrs, :is_default) || Map.get(attrs, "is_default") do
          unset_defaults(filter_set.user_id, filter_set.domain)
          attrs
        else
          attrs
        end

      filter_set
      |> FilterSet.changeset(attrs)
      |> Repo.update()
    else
      false -> {:error, :unauthorized}
      error -> error
    end
  end

  @doc """
  Deletes a filter set.
  """
  def delete_filter_set(id, user_id) do
    with {:ok, filter_set} <- get_filter_set(id, user_id),
         true <- filter_set.user_id == user_id do
      Repo.delete(filter_set)
    else
      false -> {:error, :unauthorized}
      error -> error
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking filter set changes.
  """
  def change_filter_set(%FilterSet{} = filter_set, attrs \\ %{}) do
    FilterSet.changeset(filter_set, attrs)
  end

  @doc """
  Duplicates a filter set.
  """
  def duplicate_filter_set(id, new_name, user_id) do
    with {:ok, original} <- get_filter_set(id, user_id) do
      attrs =
        Map.from_struct(original)
        |> Map.delete(:__meta__)
        |> Map.delete(:id)
        |> Map.delete(:inserted_at)
        |> Map.delete(:updated_at)
        |> Map.put(:name, new_name || "#{original.name} (Copy)")
        |> Map.put(:user_id, user_id)
        |> Map.put(:is_default, false)
        |> Map.put(:usage_count, 0)

      create_filter_set(attrs)
    end
  end

  @doc """
  Increments the usage count for a filter set.
  """
  def increment_usage_count(id) do
    from(f in FilterSet, where: f.id == ^id)
    |> Repo.update_all(inc: [usage_count: 1])

    :ok
  end

  @doc """
  Sets a filter set as default for a user/domain.
  """
  def set_default_filter_set(id, user_id) do
    with {:ok, filter_set} <- get_filter_set(id, user_id),
         true <- filter_set.user_id == user_id do
      unset_defaults(user_id, filter_set.domain)

      filter_set
      |> FilterSet.changeset(%{is_default: true})
      |> Repo.update()
    else
      false -> {:error, :unauthorized}
      error -> error
    end
  end

  @doc """
  Gets the default filter set for a user/domain.
  """
  def get_default_filter_set(user_id, domain) do
    FilterSet
    |> where([f], f.user_id == ^user_id)
    |> where([f], f.domain == ^domain)
    |> where([f], f.is_default == true)
    |> Repo.one()
  end

  @doc """
  Exports a filter set as JSON.
  """
  def export_filter_set(id, user_id) do
    with {:ok, filter_set} <- get_filter_set(id, user_id) do
      json =
        %{
          name: filter_set.name,
          description: filter_set.description,
          domain: filter_set.domain,
          filters: filter_set.filters,
          version: "1.0"
        }
        |> Jason.encode!(pretty: true)

      {:ok, json}
    end
  end

  @doc """
  Imports a filter set from JSON.
  """
  def import_filter_set(json_string, user_id) do
    with {:ok, data} <- Jason.decode(json_string),
         {:ok, _version} <- validate_version(data["version"]) do
      attrs = %{
        name: data["name"] || "Imported Filter Set",
        description: data["description"],
        domain: data["domain"],
        filters: data["filters"],
        user_id: user_id,
        is_shared: false,
        is_default: false
      }

      create_filter_set(attrs)
    else
      {:error, :invalid_json} -> {:error, "Invalid JSON format"}
      {:error, :unsupported_version} -> {:error, "Unsupported filter set version"}
      error -> error
    end
  end

  @doc """
  Generates a shareable URL for a filter set.
  """
  def generate_share_url(id, user_id, base_url) do
    with {:ok, filter_set} <- get_filter_set(id, user_id) do
      # Encode the filters as a compressed base64 string
      encoded =
        filter_set.filters
        |> Jason.encode!()
        |> :zlib.compress()
        |> Base.url_encode64(padding: false)

      url = "#{base_url}?filter_set=#{encoded}&name=#{URI.encode(filter_set.name)}"
      {:ok, url}
    end
  end

  @doc """
  Parses a filter set from a share URL.
  """
  def parse_share_url(encoded_filters, name) do
    with {:ok, compressed} <- Base.url_decode64(encoded_filters, padding: false),
         json <- :zlib.uncompress(compressed),
         {:ok, filters} <- Jason.decode(json) do
      {:ok, %{name: name || "Shared Filter Set", filters: filters}}
    else
      _ -> {:error, "Invalid share URL"}
    end
  end

  # Private functions

  defp unset_defaults(user_id, domain) do
    from(f in FilterSet,
      where: f.user_id == ^user_id and f.domain == ^domain and f.is_default == true
    )
    |> Repo.update_all(set: [is_default: false])
  end

  defp validate_version("1.0"), do: {:ok, "1.0"}
  defp validate_version(_), do: {:error, :unsupported_version}
end
