defmodule SelectoTest.SelectoCase do
  @moduledoc """
  Test case for Selecto-based tests using Ecto sandbox.
  
  This test case provides:
  - Ecto sandbox setup for test isolation
  - Database cleanup between tests 
  - Proper connection lifecycle management
  """
  
  use ExUnit.CaseTemplate
  
  using do
    quote do
      alias SelectoTest.Repo
      
      import Ecto
      import Ecto.Query
      import SelectoTest.SelectoCase
    end
  end
  
  setup tags do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(SelectoTest.Repo, shared: not tags[:async])

    # Opt-in cleanup for fixture-heavy tests that require deterministic row counts.
    # Keeping this disabled by default avoids lock contention with tests that use
    # separate Postgrex connections for query execution.
    if tags[:cleanup_db] do
      cleanup_database()
    end

    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
    :ok
  end
  
  @doc """
  Clean up database tables using Ecto in proper dependency order.
  """
  def cleanup_database do
    # Truncate in one query for speed; CASCADE handles FK dependencies and
    # RESTART IDENTITY keeps test-generated IDs deterministic.
    sql = """
    TRUNCATE TABLE
      film_actor,
      film_category,
      film,
      actor,
      category,
      language,
      inventory,
      rental,
      payment,
      staff,
      store,
      customer,
      address,
      city,
      country
    RESTART IDENTITY CASCADE
    """

    case SelectoTest.Repo.query(sql, []) do
      {:ok, _} -> :ok
      {:error, error} -> raise "Database cleanup failed: #{inspect(error)}"
    end
  end
  
  @doc """
  Insert test data using Ecto.
  """
  def insert_test_data! do
    # Basic test data
    {:ok, english} = %SelectoTest.Store.Language{name: "English"} |> SelectoTest.Repo.insert()
    {:ok, spanish} = %SelectoTest.Store.Language{name: "Spanish"} |> SelectoTest.Repo.insert()
    
    {:ok, actor1} = %SelectoTest.Store.Actor{first_name: "Alice", last_name: "Johnson"} |> SelectoTest.Repo.insert()
    {:ok, actor2} = %SelectoTest.Store.Actor{first_name: "John", last_name: "Doe"} |> SelectoTest.Repo.insert()
    {:ok, actor3} = %SelectoTest.Store.Actor{first_name: "Jane", last_name: "Smith"} |> SelectoTest.Repo.insert() 
    {:ok, actor4} = %SelectoTest.Store.Actor{first_name: "Bob", last_name: "Wilson"} |> SelectoTest.Repo.insert()
    
    {:ok, film1} = %SelectoTest.Store.Film{
      title: "Test Film 1",
      description: "A test film",
      release_year: 2023,
      language_id: english.language_id,
      rental_duration: 3,
      rental_rate: Decimal.new("4.99"),
      length: 120,
      replacement_cost: Decimal.new("19.99"),
      rating: :G  # Changed to G rating for join filter tests
    } |> SelectoTest.Repo.insert()
    
    {:ok, film2} = %SelectoTest.Store.Film{
      title: "Test Film 2", 
      description: "Another test film",
      release_year: 2024,
      language_id: spanish.language_id,
      rental_duration: 5,
      rental_rate: Decimal.new("3.99"),
      length: 150,
      replacement_cost: Decimal.new("24.99"),
      rating: :PG
    } |> SelectoTest.Repo.insert()
    
    # Create film_actor relationships for join tests
    {:ok, film_actor1} = %SelectoTest.Store.FilmActor{
      actor_id: actor1.actor_id,
      film_id: film1.film_id
    } |> SelectoTest.Repo.insert()
    
    {:ok, film_actor2} = %SelectoTest.Store.FilmActor{
      actor_id: actor1.actor_id,  # Alice appears in both films
      film_id: film2.film_id
    } |> SelectoTest.Repo.insert()
    
    {:ok, film_actor3} = %SelectoTest.Store.FilmActor{
      actor_id: actor2.actor_id,  # John appears in film1
      film_id: film1.film_id
    } |> SelectoTest.Repo.insert()
    
    {:ok, film_actor4} = %SelectoTest.Store.FilmActor{
      actor_id: actor3.actor_id,  # Jane appears in film2
      film_id: film2.film_id
    } |> SelectoTest.Repo.insert()
    
    %{
      languages: %{english: english, spanish: spanish},
      actors: %{actor1: actor1, actor2: actor2, actor3: actor3, actor4: actor4},
      films: %{film1: film1, film2: film2},
      film_actors: %{film_actor1: film_actor1, film_actor2: film_actor2, film_actor3: film_actor3, film_actor4: film_actor4}
    }
  end
end
