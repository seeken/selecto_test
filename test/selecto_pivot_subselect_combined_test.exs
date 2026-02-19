defmodule SelectoPivotSubselectCombinedTest do
  use SelectoTest.SelectoCase, async: false

  setup do
    # Insert test data that matches what the tests expect
    insert_pagila_test_data()
    :ok
  end

  describe "Combined Pivot and Subselect features" do
    test "pivot from actor to film with actor subselects" do
      # Start with actors, pivot to films, but include actor data as subselects
      selecto = create_selecto()
      |> Selecto.filter([{"first_name", "PENELOPE"}])  # Filter actors
      |> Selecto.pivot(:film)                         # Pivot to films
      |> Selecto.select(["film.title", "film.rating", "film.release_year"]) # Film fields
      |> Selecto.subselect([                         # Add film data as subselect
           %{
             fields: ["title", "rating"],
             target_schema: :film,  # Use film schema
             format: :json_agg,
             alias: "film_details"
           }
         ])
      |> Selecto.order_by(["title"])

      case Selecto.execute(selecto) do
        {:ok, {rows, columns, _aliases}} ->
          assert length(rows) > 0

          # Should have film columns plus film subselect
          assert "title" in columns
          assert "rating" in columns
          assert "release_year" in columns
          assert "film_details" in columns

          [first_row | _] = rows
          [title, rating, _year, film_json] = first_row

          # Verify we have film data
          assert is_binary(title)
          assert is_binary(rating) or is_nil(rating)

          # Verify film subselect contains film data
          if film_json do
            assert is_list(film_json) or is_binary(film_json)
          end


        {:error, reason} ->
          flunk("Combined pivot+subselect failed: #{inspect(reason)}")
      end
    end

    test "pivot with multiple subselects using different aggregation formats" do
      selecto = create_selecto()
      |> Selecto.filter([{"last_name", "WAHLBERG"}])
      |> Selecto.pivot(:film)
      |> Selecto.select(["film.title", "film.length"])
      |> Selecto.subselect([
           # JSON aggregation of film details
           %{
             fields: ["title", "rating"],
             target_schema: :film,
             format: :json_agg,
             alias: "films_json"
           },
           # Count of films
           %{
             fields: ["film_id"],
             target_schema: :film,
             format: :count,
             alias: "film_count"
           },
           # String list of film titles
           %{
             fields: ["title"],
             target_schema: :film,
             format: :string_agg,
             alias: "film_titles",
             separator: ", "
           }
         ])

      case Selecto.execute(selecto) do
        {:ok, {rows, columns, _aliases}} ->
          assert length(rows) > 0

          # Should have all the columns
          expected_columns = ["title", "length", "films_json", "film_count", "film_titles"]
          Enum.each(expected_columns, fn col ->
            assert col in columns, "Missing column: #{col}"
          end)

          [first_row | _] = rows
          [title, length, films_json, film_count, film_titles] = first_row

          assert is_binary(title)
          assert is_integer(length) or is_nil(length)
          assert is_integer(film_count)

          if films_json, do: assert(is_list(films_json) or is_binary(films_json))
          if film_titles, do: assert(is_binary(film_titles))


        {:error, reason} ->
          flunk("Multiple format subselects with pivot failed: #{inspect(reason)}")
      end
    end

    test "pivot with filtered and ordered subselects" do
      # Pivot to films but only show R-rated films in subselects, ordered by year
      selecto = create_selecto()
      |> Selecto.filter([{"first_name", "TOM"}])
      |> Selecto.pivot(:film)
      |> Selecto.select(["film.title", "film.rating"])
      |> Selecto.subselect([
           %{
             fields: ["title", "release_year", "rating"],
             target_schema: :film,
             format: :json_agg,
             alias: "other_films_by_actors",
             filters: [{"rating", "R"}],  # Only R-rated films
             order_by: [{:desc, :release_year}]
           }
         ])
      |> Selecto.order_by(["title"])

      case Selecto.execute(selecto) do
        {:ok, {rows, columns, _aliases}} ->
          assert length(rows) > 0
          assert "other_films_by_actors" in columns

          [first_row | _] = rows
          [_title, _rating, other_films] = first_row

          # other_films should contain R-rated films ordered by year
          if other_films do
            assert is_list(other_films) or is_binary(other_films)
          end

        {:error, reason} ->
          flunk("Filtered/ordered subselect with pivot failed: #{inspect(reason)}")
      end
    end

    test "complex pivot chain with subselects" do
      # More complex scenario: pivot through multiple relationships
      # This tests the limits of the join path resolution
      selecto = create_selecto()
      |> Selecto.filter([{"first_name", "JULIA"}, {"last_name", "MCQUEEN"}]) # Specific actor
      |> Selecto.pivot(:film)  # Get their films
      |> Selecto.select(["film.title", "film.rating", "film.length"])
      |> Selecto.subselect([
           # All films by these actors
           %{
             fields: ["title", "rating"],
             target_schema: :film,
             format: :json_agg,
             alias: "related_films"
           }
         ])
                  |> Selecto.filter([{"rating", "PG"}])  # Additional filter on pivot target (films)

      case Selecto.execute(selecto) do
        {:ok, {rows, columns, _aliases}} ->
          if length(rows) > 0 do
            assert "related_films" in columns

            [first_row | _] = rows
            [title, rating, _length, related_films] = first_row

            assert rating == "PG"  # Should match our additional filter
            assert is_binary(title)
            if related_films, do: assert(is_list(related_films) or is_binary(related_films))
          else
            # No results found for this filter
            :ok
          end

        {:error, reason} ->
          flunk("Complex pivot+subselect failed: #{inspect(reason)}")
      end
    end

    test "pivot with exists strategy and subselects" do
      selecto = create_selecto()
      |> Selecto.filter([{"first_name", "NICK"}])
      |> Selecto.pivot(:film, subquery_strategy: :exists)  # Use EXISTS instead of IN
      |> Selecto.select(["film.title", "film.description"])
      |> Selecto.subselect([
           %{
             fields: ["title"],
             target_schema: :film,
             format: :string_agg,
             alias: "film_titles",
             separator: " & "
           }
         ])

      case Selecto.execute(selecto) do
        {:ok, {rows, columns, _aliases}} ->
          assert length(rows) > 0
          assert "film_titles" in columns

          [first_row | _] = rows
          [_title, _description, film_titles] = first_row

          # Should include film titles
          if film_titles do
            assert is_binary(film_titles)
          end

        {:error, reason} ->
          flunk("EXISTS pivot with subselect failed: #{inspect(reason)}")
      end
    end
  end

  describe "SQL generation for combined features" do
    test "combined features produce valid SQL structure" do
      selecto = create_selecto()
      |> Selecto.filter([{"first_name", "TEST"}])
      |> Selecto.pivot(:film)
      |> Selecto.select(["film.title"])
      |> Selecto.subselect([
           %{
             fields: ["title"],
             target_schema: :film,
             format: :json_agg,
             alias: "films"
           }
         ])

      {sql, params} = Selecto.to_sql(selecto)

      # Should contain pivot structure (main FROM is film table)
      assert sql =~ "FROM film"

      # Should contain pivot subquery (IN or EXISTS)
      assert sql =~ "IN (" or sql =~ "EXISTS ("

      # Should contain subselect correlated subquery
      assert sql =~ "json_agg"

      # Should have multiple SELECT keywords (main + subqueries)
      select_count = (String.split(sql, "SELECT") |> length()) - 1
      assert select_count >= 2  # At least main SELECT and subselect SELECT

      # Should have filter parameter
      assert "TEST" in params

    end

    test "complex combined query performance validation" do
      # This test verifies that complex queries are generated without errors
      # Performance would need to be tested separately with EXPLAIN ANALYZE
      selecto = create_selecto()
      |> Selecto.filter([{"first_name", "PENELOPE"}])
      |> Selecto.pivot(:film, subquery_strategy: :exists)
      |> Selecto.select(["film.title", "film.rating", "film.length", "film.release_year"])
      |> Selecto.subselect([
           %{
             fields: ["title", "rating"],
             target_schema: :film,
             format: :json_agg,
             alias: "all_films",
             order_by: [:title, :rating]
           },
           %{
             fields: ["film_id"],
             target_schema: :film,
             format: :count,
             alias: "film_count"
           }
         ])
      |> Selecto.order_by([{:desc, "release_year"}, "title"])

      {sql, params} = Selecto.to_sql(selecto)

      # Should generate without syntax errors
      assert is_binary(sql)
      assert is_list(params)

      # Should be reasonably complex query
      assert String.length(sql) > 200  # Complex queries should be substantial

    end
  end

  describe "Error handling in combined scenarios" do
    test "invalid pivot target with subselects" do
      assert_raise ArgumentError, ~r/Invalid pivot configuration/, fn ->
        create_selecto()
        |> Selecto.pivot(:invalid_schema)
        |> Selecto.subselect(["actor.first_name"])
      end
    end

    test "invalid subselect target with pivot" do
      assert_raise ArgumentError, ~r/Target schema.*not found/, fn ->
        create_selecto()
        |> Selecto.pivot(:film)
        |> Selecto.subselect(["invalid_schema.field"])
      end
    end
  end

  # Helper functions
  defp create_selecto do
    SelectoTest.PagilaDomain.actors_domain()
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


  defp insert_pagila_test_data do
    # Create test data that matches what the tests expect
    # This simulates the Pagila dataset structure

    # Insert languages
    {:ok, english} = %SelectoTest.Store.Language{name: "English"} |> SelectoTest.Repo.insert()

    # Insert actors that the tests look for
    {:ok, penelope} = %SelectoTest.Store.Actor{first_name: "PENELOPE", last_name: "GUINESS"} |> SelectoTest.Repo.insert()
    {:ok, wahlberg} = %SelectoTest.Store.Actor{first_name: "NICK", last_name: "WAHLBERG"} |> SelectoTest.Repo.insert()
    {:ok, tom} = %SelectoTest.Store.Actor{first_name: "TOM", last_name: "MIRANDA"} |> SelectoTest.Repo.insert()
    {:ok, julia} = %SelectoTest.Store.Actor{first_name: "JULIA", last_name: "MCQUEEN"} |> SelectoTest.Repo.insert()

    # Insert films
    {:ok, film1} = %SelectoTest.Store.Film{
      title: "ACADEMY DINOSAUR",
      description: "A Epic Drama of a Feminist And a Mad Scientist who must Battle a Teacher in The Canadian Rockies",
      release_year: 2006,
      language_id: english.language_id,
      rental_duration: 6,
      rental_rate: Decimal.new("0.99"),
      length: 86,
      replacement_cost: Decimal.new("20.99"),
      rating: :PG
    } |> SelectoTest.Repo.insert()

    {:ok, film2} = %SelectoTest.Store.Film{
      title: "ACE GOLDFINGER",
      description: "A Astounding Epistle of a Database Administrator And a Explorer who must Find a Car in Ancient China",
      release_year: 2006,
      language_id: english.language_id,
      rental_duration: 3,
      rental_rate: Decimal.new("4.99"),
      length: 48,
      replacement_cost: Decimal.new("12.99"),
      rating: :G
    } |> SelectoTest.Repo.insert()

    {:ok, film3} = %SelectoTest.Store.Film{
      title: "ADAPTATION HOLES",
      description: "A Astounding Reflection of a Lumberjack And a Car who must Sink a Lumberjack in A Baloon Factory",
      release_year: 2006,
      language_id: english.language_id,
      rental_duration: 7,
      rental_rate: Decimal.new("2.99"),
      length: 50,
      replacement_cost: Decimal.new("18.99"),
      rating: :"NC-17"
    } |> SelectoTest.Repo.insert()

    # Create film_actor relationships
    %SelectoTest.Store.FilmActor{actor_id: penelope.actor_id, film_id: film1.film_id} |> SelectoTest.Repo.insert()
    %SelectoTest.Store.FilmActor{actor_id: penelope.actor_id, film_id: film2.film_id} |> SelectoTest.Repo.insert()
    %SelectoTest.Store.FilmActor{actor_id: wahlberg.actor_id, film_id: film1.film_id} |> SelectoTest.Repo.insert()
    %SelectoTest.Store.FilmActor{actor_id: tom.actor_id, film_id: film2.film_id} |> SelectoTest.Repo.insert()
    %SelectoTest.Store.FilmActor{actor_id: julia.actor_id, film_id: film3.film_id} |> SelectoTest.Repo.insert()
  end
end
