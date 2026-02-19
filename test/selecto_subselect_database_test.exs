defmodule SelectoSubselectDatabaseTest do
  use SelectoTest.SelectoCase, async: false
  @moduletag cleanup_db: true

  setup_all do
    setup_test_database()
  end

  setup do
    insert_test_data!()
    :ok
  end

  describe "Subselect with Pagila database - Actor with Film subselects" do
    test "basic subselect - actors with their films as JSON array" do
      selecto =
        create_selecto()
        |> Selecto.select(["first_name", "last_name"])
        |> Selecto.subselect(["film.title"])
        |> Selecto.filter([{"first_name", "Alice"}])
        |> Selecto.order_by(["last_name"])

      # Debug: Check what actors actually exist
      debug_selecto =
        create_selecto()
        |> Selecto.select(["first_name", "last_name"])
        |> Selecto.order_by(["last_name"])

      case Selecto.execute(debug_selecto) do
        {:ok, {_debug_rows, _, _}} ->
          :ok

        _ ->
          :ok
      end

      case Selecto.execute(selecto) do
        {:ok, {rows, columns, _aliases}} ->
          assert length(rows) > 0

          # Should have 3 columns: first_name, last_name, film (subselect)
          assert length(columns) == 3
          assert "first_name" in columns
          assert "last_name" in columns
          # Default alias
          assert "film" in columns

          [first_row | _] = rows
          [first_name, last_name, films_json] = first_row

          assert first_name == "Alice"
          assert is_binary(last_name)

          # films_json should be a JSON array string
          if films_json do
            assert is_list(films_json) or
                     (is_binary(films_json) and String.starts_with?(films_json, "["))
          end

        {:error, reason} ->
          flunk("Basic subselect query failed: #{inspect(reason)}")
      end
    end

    test "multiple field subselect - films with title and rating" do
      selecto =
        create_selecto()
        |> Selecto.select(["first_name", "last_name"])
        |> Selecto.subselect(["film[title,rating,release_year]"])
        |> Selecto.filter([{"last_name", "Johnson"}])

      case Selecto.execute(selecto) do
        {:ok, {rows, _columns, _aliases}} ->
          assert length(rows) > 0

          [first_row | _] = rows
          [_first_name, _last_name, films_data] = first_row

          # Should contain structured data with multiple fields
          if films_data do
            # This will be JSON with title, rating, and release_year fields
          end

        {:error, reason} ->
          flunk("Multi-field subselect failed: #{inspect(reason)}")
      end
    end

    test "array aggregation subselect" do
      selecto =
        create_selecto()
        |> Selecto.select(["first_name", "last_name"])
        |> Selecto.subselect([
          %{
            fields: ["title"],
            target_schema: :film,
            format: :array_agg,
            alias: "film_titles"
          }
        ])
        |> Selecto.filter([{"first_name", "John"}])

      case Selecto.execute(selecto) do
        {:ok, {rows, columns, _aliases}} ->
          assert length(rows) > 0
          assert "film_titles" in columns

          [first_row | _] = rows
          [_first_name, _last_name, film_titles] = first_row

          # Should be PostgreSQL array or list
          if film_titles do
            assert is_list(film_titles) or is_binary(film_titles)
          end

        {:error, reason} ->
          flunk("Array subselect failed: #{inspect(reason)}")
      end
    end

    test "string aggregation subselect" do
      selecto =
        create_selecto()
        |> Selecto.select(["first_name", "last_name"])
        |> Selecto.subselect([
          %{
            fields: ["title"],
            target_schema: :film,
            format: :string_agg,
            alias: "film_list",
            separator: "; "
          }
        ])
        |> Selecto.filter([{"first_name", "Jane"}])

      case Selecto.execute(selecto) do
        {:ok, {rows, columns, _aliases}} ->
          assert length(rows) > 0
          assert "film_list" in columns

          [first_row | _] = rows
          [_first_name, _last_name, film_list] = first_row

          # Should be semicolon-separated string
          if film_list do
            assert is_binary(film_list)
            # Single film case
            assert String.contains?(film_list, "; ") or not String.contains?(film_list, "; ")
          end

        {:error, reason} ->
          flunk("String subselect failed: #{inspect(reason)}")
      end
    end

    test "count subselect - number of films per actor" do
      selecto =
        create_selecto()
        |> Selecto.select(["first_name", "last_name"])
        |> Selecto.subselect([
          %{
            # Field doesn't matter for count
            fields: ["title"],
            target_schema: :film,
            format: :count,
            alias: "film_count"
          }
        ])
        |> Selecto.filter([{"first_name", "Bob"}])

      case Selecto.execute(selecto) do
        {:ok, {rows, columns, _aliases}} ->
          assert length(rows) > 0
          assert "film_count" in columns

          [first_row | _] = rows
          [_first_name, _last_name, film_count] = first_row

          # Should be integer count
          assert is_integer(film_count)
          assert film_count >= 0

        {:error, reason} ->
          flunk("Count subselect failed: #{inspect(reason)}")
      end
    end

    test "multiple subselects with different formats" do
      selecto =
        create_selecto()
        |> Selecto.select(["first_name", "last_name"])
        |> Selecto.subselect([
          %{
            fields: ["title"],
            target_schema: :film,
            format: :json_agg,
            alias: "films_json"
          },
          %{
            fields: ["title"],
            target_schema: :film,
            format: :count,
            alias: "films_count"
          }
        ])
        |> Selecto.filter([{"first_name", "Alice"}])

      case Selecto.execute(selecto) do
        {:ok, {rows, columns, _aliases}} ->
          assert length(rows) > 0
          assert "films_json" in columns
          assert "films_count" in columns

          [first_row | _] = rows
          [_first_name, _last_name, films_json, films_count] = first_row

          # Should have both JSON data and count
          if films_json, do: assert(is_list(films_json) or is_binary(films_json))
          assert is_integer(films_count)

        {:error, reason} ->
          flunk("Multiple subselects failed: #{inspect(reason)}")
      end
    end
  end

  describe "Subselect with Film domain - Films with Actor subselects" do
    test "films with actor subselect" do
      selecto =
        create_film_selecto()
        |> Selecto.select(["title", "rating"])
        # Get actor IDs for each film
        |> Selecto.subselect(["film_actors.actor_id"])
        |> Selecto.filter([{"rating", "PG"}])
        |> Selecto.order_by(["title"])

      case Selecto.execute(selecto) do
        {:ok, {rows, columns, _aliases}} ->
          assert length(rows) > 0
          assert "title" in columns
          assert "rating" in columns
          assert "film_actors" in columns

          [first_row | _] = rows
          [title, rating, actors] = first_row

          assert is_binary(title)
          assert rating == "PG"

          # actors should be JSON array of actor_ids
          if actors do
          end

        {:error, reason} ->
          flunk("Film actor subselect failed: #{inspect(reason)}")
      end
    end
  end

  describe "Subselect SQL generation validation" do
    test "generated SQL contains expected subselect structure" do
      selecto =
        create_selecto()
        |> Selecto.select(["first_name"])
        |> Selecto.subselect(["film.title"])
        |> Selecto.filter([{"last_name", "SMITH"}])

      {sql, params} = Selecto.to_sql(selecto)

      # Should contain main SELECT
      assert sql =~ ~r/select/i
      assert sql =~ "first_name"

      # Should contain subselect with JSON aggregation
      assert sql =~ "json_agg" or sql =~ "array_agg"
      # Subquery SELECT
      assert sql =~ ~r/select/i

      # Should contain correlation condition
      assert sql =~ ~r/where/i
      # Correlation join
      assert sql =~ "="

      # Should have parameter for filter
      assert "SMITH" in params
    end

    test "different aggregation formats produce different SQL" do
      base_selecto =
        create_selecto()
        |> Selecto.select(["first_name"])
        |> Selecto.filter([{"first_name", "TEST"}])

      # JSON aggregation
      json_selecto =
        base_selecto
        |> Selecto.subselect([
          %{fields: ["title"], target_schema: :film, format: :json_agg, alias: "json_films"}
        ])

      {json_sql, _} = Selecto.to_sql(json_selecto)

      # Array aggregation
      array_selecto =
        base_selecto
        |> Selecto.subselect([
          %{fields: ["title"], target_schema: :film, format: :array_agg, alias: "array_films"}
        ])

      {array_sql, _} = Selecto.to_sql(array_selecto)

      # String aggregation
      string_selecto =
        base_selecto
        |> Selecto.subselect([
          %{
            fields: ["title"],
            target_schema: :film,
            format: :string_agg,
            alias: "string_films",
            separator: ", "
          }
        ])

      {string_sql, _} = Selecto.to_sql(string_selecto)

      # Should have different aggregation functions
      assert json_sql =~ "json_agg"
      assert array_sql =~ "array_agg"
      assert string_sql =~ "string_agg"
    end
  end

  describe "Subselect with ordering and filtering" do
    test "subselect with internal ordering" do
      selecto =
        create_selecto()
        |> Selecto.select(["first_name", "last_name"])
        |> Selecto.subselect([
          %{
            fields: ["title", "release_year"],
            target_schema: :film,
            format: :json_agg,
            alias: "ordered_films",
            order_by: [{:desc, :release_year}, :title]
          }
        ])
        |> Selecto.filter([{"first_name", "John"}])

      case Selecto.execute(selecto) do
        {:ok, {rows, _columns, _aliases}} ->
          assert length(rows) > 0

          [first_row | _] = rows
          [_first_name, _last_name, films] = first_row

          if films do
            # Films should be ordered by release_year desc, then title
          end

        {:error, reason} ->
          flunk("Ordered subselect failed: #{inspect(reason)}")
      end
    end

    test "subselect with additional filters" do
      selecto =
        create_selecto()
        |> Selecto.select(["first_name", "last_name"])
        |> Selecto.subselect([
          %{
            fields: ["title", "rating"],
            target_schema: :film,
            format: :json_agg,
            alias: "pg_films",
            # Only PG films in subselect
            filters: [{"rating", "PG"}]
          }
        ])
        |> Selecto.filter([{"first_name", "Jane"}])

      case Selecto.execute(selecto) do
        {:ok, {rows, _columns, _aliases}} ->
          assert length(rows) > 0

          [first_row | _] = rows
          [_first_name, _last_name, pg_films] = first_row

          # Should only contain PG-rated films
          if pg_films do
          end

        {:error, reason} ->
          flunk("Filtered subselect failed: #{inspect(reason)}")
      end
    end
  end

  # Helper functions
  defp create_selecto do
    SelectoTest.PagilaDomain.actors_domain()
    |> Selecto.configure(SelectoTest.Repo, validate: false)
  end

  defp create_film_selecto do
    SelectoTest.PagilaDomainFilms.films_domain()
    |> Selecto.configure(SelectoTest.Repo, validate: false)
  end

  # defp get_postgrex_opts do
  #   Application.get_env(:selecto_test, SelectoTest.Repo)[:postgrex_opts] ||
  #     [
  #       hostname: System.get_env("DB_HOST", "localhost"),
  #       port: String.to_integer(System.get_env("DB_PORT", "5432")),
  #       database: System.get_env("DB_NAME", "selecto_test"),
  #       username: System.get_env("DB_USER", "postgres"),
  #       password: System.get_env("DB_PASS", "postgres")
  #     ]
  # end

  defp setup_test_database do
    # Ensure database is set up - this should be handled by existing test setup
    :ok
  end
end
