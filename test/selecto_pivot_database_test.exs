defmodule SelectoPivotDatabaseTest do
  use SelectoTest.SelectoCase, async: false

  # Import the domain modules needed for testing
  # alias SelectoTest.PagilaDomain  # Unused
  # alias SelectoTest.PagilaDomainFilms  # Unused

  setup_all do
    setup_test_database()
  end

  describe "Pivot with Pagila database - Actor to Film pivot" do
    test "pivot from actor to film with actor filter" do
      selecto =
        create_selecto()
        |> Selecto.filter([{"first_name", "PENELOPE"}])
        |> Selecto.pivot(:film)
        |> Selecto.select(["film.title", "film.release_year", "film.rating"])
        |> Selecto.order_by(["film.title"])

      case Selecto.execute(selecto) do
        {:ok, {rows, _columns, _aliases}} ->
          # Should get films that have PENELOPE actors
          assert length(rows) > 0

          # Verify we're getting film data, not actor data
          [first_row | _] = rows
          [title, year, rating] = first_row

          assert is_binary(title)
          assert is_integer(year) or is_nil(year)
          assert is_binary(rating) or is_nil(rating)

        {:error, reason} ->
          flunk("Pivot query failed: #{inspect(reason)}")
      end
    end

    test "pivot with multiple actor filters" do
      selecto =
        create_selecto()
        |> Selecto.filter([{"first_name", "PENELOPE"}, {"last_name", "GUINESS"}])
        |> Selecto.pivot(:film)
        |> Selecto.select(["film.title", "film.description"])

      case Selecto.execute(selecto) do
        {:ok, {rows, _columns, _aliases}} ->
          # Should get films for the specific actor PENELOPE GUINESS
          assert length(rows) > 0

        {:error, reason} ->
          flunk("Multi-filter pivot failed: #{inspect(reason)}")
      end
    end

    test "pivot with EXISTS strategy" do
      selecto =
        create_selecto()
        |> Selecto.filter([{"first_name", "PENELOPE"}])
        |> Selecto.pivot(:film, subquery_strategy: :exists)
        |> Selecto.select(["film.title", "film.length"])

      case Selecto.execute(selecto) do
        {:ok, {rows, _columns, _aliases}} ->
          assert length(rows) > 0

        {:error, reason} ->
          flunk("EXISTS pivot strategy failed: #{inspect(reason)}")
      end
    end

    test "pivot without preserving filters" do
      selecto =
        create_selecto()
        |> Selecto.filter([{"first_name", "PENELOPE"}])
        |> Selecto.pivot(:film, preserve_filters: false)
        |> Selecto.select(["film.title"])

      case Selecto.execute(selecto) do
        {:ok, {rows, _columns, _aliases}} ->
          # Without preserved filters, should get all films
          assert length(rows) > 0

        # Should be more films than with preserved filters

        {:error, reason} ->
          flunk("Non-preserving pivot failed: #{inspect(reason)}")
      end
    end
  end

  describe "Pivot with Film domain - Film to Actor pivot" do
    test "pivot from film to actor with rating filter" do
      selecto =
        create_film_selecto()
        |> Selecto.filter([{"rating", "PG"}])
        # Pivot to film_actors junction table
        |> Selecto.pivot(:film_actors)
        # Then pivot to actor table
        |> Selecto.pivot(:actor)
        |> Selecto.select(["actor.actor_id"])

      case Selecto.execute(selecto) do
        {:ok, {rows, _columns, _aliases}} ->
          assert length(rows) > 0

          # Should get actor IDs from PG-13 films
          [first_row | _] = rows
          [actor_id] = first_row
          assert is_integer(actor_id)

        {:error, reason} ->
          flunk("Film to actor pivot failed: #{inspect(reason)}")
      end
    end

    test "complex pivot through multiple tables" do
      # This tests pivoting from film -> film_actor -> actor (if we had that path)
      selecto =
        create_film_selecto()
        |> Selecto.filter([{"rating", "NC-17"}])
        |> Selecto.pivot(:film_actors)
        |> Selecto.pivot(:actor)
        |> Selecto.select(["actor.actor_id"])
        |> Selecto.order_by([{:desc, "actor.actor_id"}])

      case Selecto.execute(selecto) do
        {:ok, {rows, _columns, _aliases}} ->
          assert length(rows) > 0

        {:error, reason} ->
          flunk("Complex pivot failed: #{inspect(reason)}")
      end
    end
  end

  describe "Pivot SQL generation validation" do
    test "generated SQL contains expected pivot structure" do
      selecto =
        create_selecto()
        |> Selecto.filter([{"first_name", "PENELOPE"}])
        |> Selecto.pivot(:film)
        |> Selecto.select(["film.title"])

      {sql, params} = Selecto.to_sql(selecto)

      # Should contain pivot target table
      assert sql =~ ~r/FROM film/i

      # Should contain subquery structure
      assert sql =~ "IN (" or sql =~ "EXISTS ("

      # Should contain original table in subquery
      assert sql =~ "actor"

      # Should have parameter for filter
      assert "PENELOPE" in params
    end

    test "different strategies produce different SQL patterns" do
      base_selecto =
        create_selecto()
        |> Selecto.filter([{"first_name", "PENELOPE"}])
        |> Selecto.select(["film.title"])

      # IN strategy
      in_selecto = base_selecto |> Selecto.pivot(:film, subquery_strategy: :in)
      {in_sql, _} = Selecto.to_sql(in_selecto)

      # EXISTS strategy
      exists_selecto = base_selecto |> Selecto.pivot(:film, subquery_strategy: :exists)
      {exists_sql, _} = Selecto.to_sql(exists_selecto)

      # Should have different patterns
      assert in_sql =~ "IN ("
      assert exists_sql =~ "EXISTS ("

      # Both should work with same base structure
      assert in_sql =~ ~r/FROM film/i
      assert exists_sql =~ ~r/FROM film/i
    end
  end

  # Helper functions
  defp create_selecto do
    # Create a Postgrex connection for Selecto to use
    {:ok, conn} = Postgrex.start_link(get_postgrex_opts())

    SelectoTest.PagilaDomain.actors_domain()
    |> Selecto.configure(conn, validate: false)
  end

  defp create_film_selecto do
    # Create a Postgrex connection for Selecto to use
    {:ok, conn} = Postgrex.start_link(get_postgrex_opts())

    SelectoTest.PagilaDomainFilms.films_domain()
    |> Selecto.configure(conn, validate: false)
  end

  defp get_postgrex_opts do
    # Get from Repo config if available, otherwise use environment/defaults
    Application.get_env(:selecto_test, SelectoTest.Repo)[:postgrex_opts] ||
      [
        hostname: System.get_env("DB_HOST", "localhost"),
        port: String.to_integer(System.get_env("DB_PORT", "5432")),
        database: System.get_env("DB_NAME", "selecto_test_test"),
        username: System.get_env("DB_USER", "postgres"),
        password: System.get_env("DB_PASS", "postgres")
      ]
  end

  defp setup_test_database do
    # Load Pagila sample data for testing
    pagila_data_file = Path.join([__DIR__, "..", "priv", "sql", "pagila-data.sql"])

    if File.exists?(pagila_data_file) do
      # Get database config
      repo_config = SelectoTest.Repo.config()
      database = repo_config[:database]
      username = repo_config[:username] || "postgres"
      hostname = repo_config[:hostname] || "localhost"
      port = repo_config[:port] || 5432

      # Use psql to execute the data file
      psql_cmd =
        ~s(PGPASSWORD="#{repo_config[:password]}" psql -h #{hostname} -p #{port} -U #{username} -d #{database} -f #{pagila_data_file})

      case System.cmd("sh", ["-c", psql_cmd], stderr_to_stdout: true) do
        {_output, 0} ->
          :ok

        {output, _exit_code} ->
          if String.contains?(output, "psql: command not found") do
            # psql not available, skip silently
            :ok
          else
            # Failed to load data, but continue
            :ok
          end
      end
    else
      # Data file not found, skip silently
      :ok
    end

    :ok
  end
end
