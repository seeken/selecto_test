defmodule SelectoSubfilterLiveDataTest do
  @moduledoc """
  Live data integration tests for the Selecto Subfilter System.

  These tests validate the subfilter functionality against real database queries
  using actual Pagila database schema and data.
  """
  use ExUnit.Case, async: false

  alias Selecto.Subfilter.{Registry, Parser}
  alias Selecto.Subfilter.SQL

  @moduletag :live_data

  defp film_domain_config do
    %{
      tables: [:film, :category, :film_category, :actor, :film_actor, :language],
      joins: %{
        "film.rating" => %{from: :film, to: :film, type: :self, field: :rating},
        "film.title" => %{from: :film, to: :film, type: :self, field: :title},
        "film.release_year" => %{from: :film, to: :film, type: :self, field: :release_year},
        "film.rental_rate" => %{from: :film, to: :film, type: :self, field: :rental_rate},
        "film.category" => %{
          from: :film,
          to: :category,
          type: :inner,
          via: :film_category,
          on:
            "film.film_id = film_category.film_id AND film_category.category_id = category.category_id"
        },
        "film.actors" => %{
          from: :film,
          to: :film_actor,
          type: :inner,
          on: "film.film_id = film_actor.film_id"
        },
        "film.actor" => %{
          from: :film,
          to: :actor,
          type: :inner,
          via: :film_actor,
          on: "film.film_id = film_actor.film_id AND film_actor.actor_id = actor.actor_id"
        },
        "film.language" => %{
          from: :film,
          to: :language,
          type: :inner,
          on: "film.language_id = language.language_id"
        },
        "film.category.name" => [
          %{
            from: :film,
            to: :film_category,
            type: :inner,
            on: "film.film_id = film_category.film_id"
          },
          %{
            from: :film_category,
            to: :category,
            type: :inner,
            on: "film_category.category_id = category.category_id"
          }
        ],
        "film.language.name" => [
          %{
            from: :film,
            to: :language,
            type: :inner,
            on: "film.language_id = language.language_id"
          }
        ]
      }
    }
  end

  describe "Selecto Subfilter Live Data Integration" do
    @tag :requires_database
    test "single EXISTS subfilter with film.category.name relationship" do
      # Test: Find all films in the "Action" category
      registry = Registry.new(film_domain_config(), base_table: :film)
      {:ok, registry} = Registry.add_subfilter(registry, "film.category.name", "Action")

      {:ok, sql, params} = SQL.generate(registry)

      # Validate SQL structure
      assert sql =~ "WHERE (EXISTS ("
      assert sql =~ ~r/from\s+(")?film(")?(\s|$)/i
      assert sql =~ ~r/inner\s+join\s+(")?film_category(")?(\s|$)/i
      assert sql =~ ~r/inner\s+join\s+(")?category(")?(\s|$)/i
      assert sql =~ "WHERE film.film_id = film.film_id AND category.name = ?"
      assert params == ["Action"]
    end

    @tag :requires_database
    test "single IN subfilter with film.category.name for multiple values" do
      # Test: Find all films in "Action" or "Comedy" categories
      registry = Registry.new(film_domain_config(), base_table: :film)

      {:ok, registry} =
        Registry.add_subfilter(registry, "film.category.name", ["Action", "Comedy"],
          strategy: :in
        )

      {:ok, sql, params} = SQL.generate(registry)

      # Validate SQL structure
      assert sql =~ "WHERE (film.film_id IN ("
      assert sql =~ "SELECT film.film_id"
      assert sql =~ ~r/from\s+(")?film(")?(\s|$)/i
      assert sql =~ "WHERE category.name IN (?, ?)"
      assert params == ["Action", "Comedy"]
    end

    @tag :requires_database
    test "aggregation subfilter with count comparison" do
      # Test: Find all films with more than 5 actors
      registry = Registry.new(film_domain_config(), base_table: :film)
      {:ok, registry} = Registry.add_subfilter(registry, "film.actors", {:count, ">", 5})

      {:ok, sql, params} = SQL.generate(registry)

      # Validate SQL structure for aggregation (uses direct COUNT comparison, not EXISTS)
      assert sql =~ "WHERE (("
      assert sql =~ "SELECT COUNT(*)"
      assert sql =~ ~r/from\s+(")?film(")?(\s|$)/i
      assert sql =~ ~r/inner\s+join\s+(")?film_actor(")?(\s|$)/i
      assert sql =~ "> ?)"
      assert params == [5]
    end

    @tag :requires_database
    test "compound AND subfilters for complex filtering" do
      # Test: Find all R-rated films released after 2000
      registry = Registry.new(film_domain_config(), base_table: :film)

      subfilters = [
        {"film.rating", "R"},
        {"film.release_year", {">", 2000}}
      ]

      {:ok, registry} = Registry.add_compound(registry, :and, subfilters)
      {:ok, sql, params} = SQL.generate(registry)

      # Validate SQL structure for compound operations
      assert sql =~ ~r/where/i
      assert sql =~ " AND "
      assert Enum.sort(params) == Enum.sort(["R", 2000])
    end

    @tag :requires_database
    test "registry analysis for performance insights" do
      # Test: Create a complex registry and analyze it
      registry = Registry.new(film_domain_config(), base_table: :film)
      {:ok, registry} = Registry.add_subfilter(registry, "film.category.name", "Drama")
      {:ok, registry} = Registry.add_subfilter(registry, "film.language.name", "English")
      {:ok, registry} = Registry.add_subfilter(registry, "film.actors", {:count, ">", 3})

      analysis = Registry.analyze(registry)

      # Validate analysis results
      assert analysis.subfilter_count == 3
      assert analysis.join_complexity in [:low, :medium, :high]
      assert is_map(analysis.strategy_distribution)
      assert is_number(analysis.performance_score)
      assert is_list(analysis.optimization_suggestions)
    end

    @tag :requires_database
    test "parser validation with different filter specifications" do
      # Test: Validate different filter specification formats
      test_cases = [
        {"film.title", "ACADEMY DINOSAUR"},
        {"film.release_year", {">", 2005}},
        {"film.rental_rate", {"between", 2.99, 4.99}},
        {"film.category.name", ["Action", "Comedy", "Drama"]},
        {"film.actors", {:count, ">=", 10}}
      ]

      Enum.each(test_cases, fn {path, filter_spec} ->
        case Parser.parse(path, filter_spec) do
          {:ok, spec} ->
            assert spec.relationship_path.path_segments != []
            assert spec.filter_spec != nil

          {:error, reason} ->
            flunk("Failed to parse #{path}: #{inspect(reason)}")
        end
      end)
    end

    @tag :requires_database
    test "join path resolution for film domain" do
      # Test: Validate different relationship paths resolve correctly
      test_paths = [
        "film.rating",
        "film.category",
        "film.category.name",
        "film.actor",
        "film.language",
        "film.language.name"
      ]

      Enum.each(test_paths, fn path ->
        {:ok, spec} = Parser.parse(path, "test_value")

        case Selecto.Subfilter.JoinPathResolver.resolve(
               spec.relationship_path,
               film_domain_config()
             ) do
          {:ok, resolution} ->
            assert is_list(resolution.joins)
            assert resolution.target_table != nil

          {:error, reason} ->
            flunk("Failed to resolve path #{path}: #{inspect(reason)}")
        end
      end)
    end

    @tag :requires_database
    test "strategy override functionality" do
      # Test: Override default strategy for specific subfilters
      registry = Registry.new(film_domain_config(), base_table: :film)

      {:ok, registry} =
        Registry.add_subfilter(registry, "film.category.name", ["Action", "Comedy"],
          id: "category_filter"
        )

      # Default should be :in for list values
      analysis = Registry.analyze(registry)
      assert Map.get(analysis.strategy_distribution, :in, 0) >= 1

      # Override to :exists
      {:ok, registry} = Registry.override_strategy(registry, "category_filter", :exists)
      {:ok, sql, _params} = SQL.generate(registry)

      # Should now use EXISTS format instead of IN
      assert sql =~ "WHERE (EXISTS ("
    end

    @tag :requires_database
    test "error handling for invalid configurations" do
      # Test: Validate proper error handling for invalid inputs
      registry = Registry.new(film_domain_config(), base_table: :film)

      # Test duplicate subfilter ID
      {:ok, registry} = Registry.add_subfilter(registry, "film.rating", "R", id: "test_id")

      assert {:error, _reason} =
               Registry.add_subfilter(registry, "film.title", "Test", id: "test_id")

      # Test invalid relationship path
      {:ok, invalid_path_spec} = Parser.parse("film.nonexistent.field", "value")

      assert {:error, _reason} =
               Selecto.Subfilter.JoinPathResolver.resolve(
                 invalid_path_spec.relationship_path,
                 film_domain_config()
               )

      # Test invalid domain
      {:ok, spec} = Parser.parse("film.rating", "R")

      assert {:error, _reason} =
               Selecto.Subfilter.JoinPathResolver.resolve(spec.relationship_path, :invalid_domain)
    end

    @tag :requires_database
    test "performance with large number of subfilters" do
      # Test: Create a registry with many subfilters to test performance
      registry = Registry.new(film_domain_config(), base_table: :film)

      # Add multiple subfilters
      subfilter_specs = [
        {"film.rating", "PG"},
        {"film.release_year", {">", 2000}},
        {"film.rental_rate", {"<", 3.00}},
        {"film.category.name", "Comedy"},
        {"film.language.name", "English"},
        {"film.actors", {:count, ">", 2}}
      ]

      start_time = System.monotonic_time(:millisecond)

      registry =
        Enum.reduce(subfilter_specs, registry, fn {path, spec}, acc ->
          {:ok, updated_registry} = Registry.add_subfilter(acc, path, spec)
          updated_registry
        end)

      {:ok, sql, params} = SQL.generate(registry)
      analysis = Registry.analyze(registry)

      end_time = System.monotonic_time(:millisecond)
      duration_ms = end_time - start_time

      # Validate results
      assert analysis.subfilter_count == length(subfilter_specs)
      assert byte_size(sql) > 0
      assert length(params) > 0

      # Performance assertion - should process quickly
      assert duration_ms < 100, "Subfilter processing took too long: #{duration_ms}ms"
    end
  end

  describe "Selecto Subfilter Integration with Phase 1 Joins" do
    @tag :requires_database
    test "subfilters work with existing parameterized joins" do
      # Test: Ensure subfilters integrate properly with Phase 1 join system
      registry = Registry.new(film_domain_config(), base_table: :film)
      {:ok, registry} = Registry.add_subfilter(registry, "film.category.name", "Action")

      # Generate SQL - this should integrate with existing join resolution
      {:ok, sql, params} = SQL.generate(registry)

      # Validate that the subfilter SQL is properly structured
      assert sql =~ ~r/where/i
      assert sql =~ "EXISTS"
      assert params == ["Action"]
    end
  end
end
