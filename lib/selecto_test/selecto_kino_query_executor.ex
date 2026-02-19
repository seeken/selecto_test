defmodule SelectoKino.QueryExecutor do
  @moduledoc """
  Query executor for SelectoKino integration.
  Handles execution of Selecto queries via remote calls.
  """

  alias SelectoTest.Repo
  import Ecto.Query

  @doc """
  Executes a Selecto query for the given domain and parameters.
  """
  def execute_query(domain_name, query_params) do
    try do
      # Get domain configuration
      domain_config =
        case SelectoKino.DomainRegistry.get_domain(domain_name) do
          {:error, _} = error -> throw(error)
          domain_config -> domain_config
        end

      # Execute a simplified query based on the parameters
      # In a real implementation, this would use full Selecto functionality
      results = execute_simple_query(domain_config, query_params)

      {:ok, results}
    rescue
      error ->
        {:error, "Query execution failed: #{Exception.message(error)}"}
    catch
      {:error, message} ->
        {:error, message}
    end
  end

  defp execute_simple_query(domain_config, query_params) do
    # Get the source table and map it to the corresponding Ecto schema module
    table = domain_config.source.source_table
    schema_module = get_schema_module(table)

    # Apply limit if specified
    limit_value =
      if limit = query_params[:limit] do
        limit
      else
        # Default limit
        50
      end

    # Execute query based on the table type
    case table do
      "actor" ->
        from(a in schema_module)
        |> select([a], %{
          actor_id: a.actor_id,
          first_name: a.first_name,
          last_name: a.last_name,
          full_name: fragment("? || ' ' || ?", a.first_name, a.last_name)
        })
        |> limit(^limit_value)
        |> Repo.all()

      "film" ->
        from(f in schema_module)
        |> select([f], %{
          film_id: f.film_id,
          title: f.title,
          release_year: f.release_year,
          length: f.length,
          rating: f.rating,
          rental_rate: f.rental_rate
        })
        |> limit(^limit_value)
        |> Repo.all()

      "author" ->
        # For blog domain - simplified since we don't have the actual Author schema yet
        []

      _ ->
        # Fallback: return empty list for unknown tables
        []
    end
  end

  defp get_schema_module(table_name) do
    case table_name do
      "actor" ->
        SelectoTest.Store.Actor

      "film" ->
        SelectoTest.Store.Film

      "category" ->
        SelectoTest.Store.Category

      "language" ->
        SelectoTest.Store.Language

      "customer" ->
        SelectoTest.Store.Customer

      "staff" ->
        SelectoTest.Store.Staff

      "store" ->
        SelectoTest.Store.Store

      "rental" ->
        SelectoTest.Store.Rental

      "payment" ->
        SelectoTest.Store.Payment

      "inventory" ->
        SelectoTest.Store.Inventory

      "address" ->
        SelectoTest.Store.Address

      "city" ->
        SelectoTest.Store.City

      "country" ->
        SelectoTest.Store.Country

      "film_actor" ->
        SelectoTest.Store.FilmActor

      "film_category" ->
        SelectoTest.Store.FilmCategory

      "film_tag" ->
        SelectoTest.Store.FilmTag

      "film_flag" ->
        SelectoTest.Store.FilmFlag

      "tag" ->
        SelectoTest.Store.Tag

      "flag" ->
        SelectoTest.Store.Flag

      _ ->
        # Fallback to a generic table name (this might still fail but provides better error)
        String.to_atom(table_name)
    end
  end
end
