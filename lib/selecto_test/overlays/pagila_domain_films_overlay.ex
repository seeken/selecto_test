defmodule SelectoTest.Overlays.PagilaDomainFilmsOverlay do
  @moduledoc """
  Overlay configuration for the Pagila Films domain.

  This overlay customizes column display formats, labels, and filter
  configurations specific to the film-centric domain view.
  """
  use Selecto.Config.OverlayDSL

  # Primary film columns
  defcolumn :film_id do
    label("Film ID")
    sortable(true)
    filterable(true)
  end

  defcolumn :title do
    label("Title")
    sortable(true)
    filterable(true)
    max_length(255)
  end

  defcolumn :description do
    label("Description")
    max_length(500)
    sortable(false)
  end

  defcolumn :release_year do
    label("Release Year")
    sortable(true)
    filterable(true)
    aggregate_functions([:min, :max, :count])
  end

  defcolumn :rental_duration do
    label("Rental Duration (days)")
    format(:number)
    aggregate_functions([:avg, :min, :max])
  end

  defcolumn :rental_rate do
    label("Rental Rate")
    format(:currency)
    precision(2)
    aggregate_functions([:sum, :avg, :min, :max])
  end

  defcolumn :length do
    label("Length (minutes)")
    format(:number)
    aggregate_functions([:avg, :min, :max, :sum])
  end

  defcolumn :replacement_cost do
    label("Replacement Cost")
    format(:currency)
    precision(2)
    aggregate_functions([:sum, :avg, :min, :max])
  end

  defcolumn :rating do
    label("MPAA Rating")
    sortable(true)
    filterable(true)
  end

  defcolumn :special_features do
    label("Special Features")
    filterable(true)
  end

  # Joined relation metadata belongs on the schemas that own these columns.
  # Defining them with defcolumn/2 would create invalid root-level fields.
  defschema(:actor, %{
    columns: %{
      first_name: %{label: "Actor First Name", sortable: true, filterable: true},
      last_name: %{label: "Actor Last Name", sortable: true, filterable: true}
    }
  })

  defschema(:language, %{
    columns: %{
      name: %{label: "Language", sortable: true, filterable: true}
    }
  })

  # Custom filters for film domain
  deffilter "title_search" do
    name("Title Search")
    type(:string)
    field("title")
    description("Search films by title")
    apply(&__MODULE__.title_search_apply/2)
  end

  deffilter "release_year_range" do
    name("Release Year Range")
    type(:integer)
    field("release_year")
    description("Filter films by release year range")
    apply(&__MODULE__.release_year_range_apply/2)
  end

  deffilter "rental_rate_range" do
    name("Rental Rate Range")
    type(:decimal)
    field("rental_rate")
    description("Filter films by rental rate")
    apply(&__MODULE__.rental_rate_range_apply/2)
  end

  deffilter "length_range" do
    name("Length Range")
    type(:integer)
    field("length")
    description("Filter films by length in minutes")
    apply(&__MODULE__.length_range_apply/2)
  end

  deffilter "has_special_feature" do
    name("Has Special Feature")
    type(:string)
    field("special_features")
    description("Filter films that have a specific special feature")
    options(["Trailers", "Commentaries", "Deleted Scenes", "Behind the Scenes"])
    apply(&__MODULE__.has_special_feature_apply/2)
  end

  def title_search_apply(_selecto, filter) do
    comp = normalize_comp(filter, "LIKE")

    case comp do
      x when x in ["NULL", "IS_EMPTY", "IS NULL"] ->
        {"title", nil}

      x when x in ["NOT_NULL", "IS_NOT_EMPTY", "IS NOT NULL"] ->
        {"title", :not_null}

      "BETWEEN" ->
        {start_value, end_value} = between_values!(filter)
        {"title", {:between, start_value, end_value}}

      "!=" ->
        {"title", {"!=", required_value!(filter)}}

      "NOT LIKE" ->
        {"title", {:not_like, "%" <> required_value!(filter) <> "%"}}

      x when x in [">", ">=", "<", "<="] ->
        {"title", {x, required_value!(filter)}}

      _ ->
        {"title", {:like, "%" <> required_value!(filter) <> "%"}}
    end
  end

  def release_year_range_apply(_selecto, filter) do
    apply_numeric_filter("release_year", :integer, filter)
  end

  def rental_rate_range_apply(_selecto, filter) do
    apply_numeric_filter("rental_rate", :decimal, filter)
  end

  def length_range_apply(_selecto, filter) do
    apply_numeric_filter("length", :integer, filter)
  end

  def has_special_feature_apply(_selecto, filter) do
    comp = normalize_comp(filter, "LIKE")

    case comp do
      x when x in ["NULL", "IS_EMPTY", "IS NULL"] ->
        {"special_features", nil}

      x when x in ["NOT_NULL", "IS_NOT_EMPTY", "IS NOT NULL"] ->
        {"special_features", :not_null}

      "IN" ->
        values = required_value_list!(filter)
        {:array_overlap, "special_features", values}

      "NOT IN" ->
        values = required_value_list!(filter)
        {:not, {:array_overlap, "special_features", values}}

      x when x in ["!=", "NOT LIKE"] ->
        {:not, {"special_features", {:contains, required_value!(filter)}}}

      _ ->
        {"special_features", {:contains, required_value!(filter)}}
    end
  end

  defp apply_numeric_filter(field, type, filter) do
    comp = normalize_comp(filter, "=")

    case comp do
      x when x in ["NULL", "IS_EMPTY", "IS NULL"] ->
        {field, nil}

      x when x in ["NOT_NULL", "IS_NOT_EMPTY", "IS NOT NULL"] ->
        {field, :not_null}

      "BETWEEN" ->
        {start_value, end_value} = between_values!(filter)
        {field, {:between, cast_numeric!(type, start_value), cast_numeric!(type, end_value)}}

      "IN" ->
        {field, {:in, required_value_list!(filter) |> Enum.map(&cast_numeric!(type, &1))}}

      "NOT IN" ->
        {field, {:not_in, required_value_list!(filter) |> Enum.map(&cast_numeric!(type, &1))}}

      x when x in ["!=", "<", ">", "<=", ">="] ->
        {field, {x, cast_numeric!(type, required_value!(filter))}}

      _ ->
        {field, cast_numeric!(type, required_value!(filter))}
    end
  end

  defp normalize_comp(filter, default) do
    to_string(Map.get(filter, "comp") || default) |> String.upcase()
  end

  defp between_values!(filter) do
    start_value = Map.get(filter, "value_start") || Map.get(filter, "value")
    end_value = Map.get(filter, "value_end") || Map.get(filter, "value2")

    cond do
      present?(start_value) and present?(end_value) ->
        {to_string(start_value), to_string(end_value)}

      present?(start_value) and is_binary(start_value) and String.contains?(start_value, ",") ->
        case String.split(start_value, ",", parts: 2) do
          [left, right] ->
            if present?(left) and present?(right) do
              {left, right}
            else
              raise ArgumentError, "BETWEEN requires start and end values"
            end

          _ ->
            raise ArgumentError, "BETWEEN requires start and end values"
        end

      true ->
        raise ArgumentError, "BETWEEN requires start and end values"
    end
  end

  defp required_value!(filter) do
    value = Map.get(filter, "value")

    if present?(value) do
      to_string(value)
    else
      raise ArgumentError, "value is required"
    end
  end

  defp required_value_list!(filter) do
    values =
      filter
      |> Map.get("value", "")
      |> to_string()
      |> String.split(",")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(not present?(&1)))

    if values == [] do
      raise ArgumentError, "at least one value is required"
    else
      values
    end
  end

  defp cast_numeric!(type, value) do
    case Ecto.Type.cast(type, value) do
      {:ok, casted} -> casted
      :error -> raise ArgumentError, "invalid #{type} value #{inspect(value)}"
    end
  end

  defp present?(value), do: value not in [nil, ""]
end
