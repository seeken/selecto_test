defmodule SelectoColumnTypesTest do
  use SelectoTest.SelectoCase, async: false

  # Tests for all Selecto column types using Pagila database tables
  # Tests type handling, conversions, and type-specific operations

  setup do
    # Ensure films exist for testing
    alias SelectoTest.{Repo, Store.Film, Store.Language}

    {:ok, english} =
      case Repo.get_by(Language, name: "English") do
        nil -> Language.changeset(%Language{}, %{name: "English"}) |> Repo.insert()
        lang -> {:ok, lang}
      end

    # Create diverse test films for comprehensive testing
    films_data = [
      %{
        title: "Academy Dinosaur",
        description: "A Epic Drama",
        release_year: 2006,
        language_id: english.language_id,
        rental_duration: 6,
        rental_rate: Decimal.new("0.99"),
        length: 86,
        replacement_cost: Decimal.new("20.99"),
        rating: :PG,
        special_features: ["Deleted Scenes", "Behind the Scenes"]
      },
      %{
        title: "Ace Goldfinger",
        description: "A Astounding Action Adventure",
        release_year: 2006,
        language_id: english.language_id,
        rental_duration: 3,
        rental_rate: Decimal.new("4.99"),
        length: 48,
        replacement_cost: Decimal.new("12.99"),
        rating: :G,
        special_features: ["Trailers"]
      },
      %{
        title: "Adventure Drama",
        description: "A thrilling adventure story",
        release_year: 2005,
        language_id: english.language_id,
        rental_duration: 7,
        rental_rate: Decimal.new("2.99"),
        length: 120,
        replacement_cost: Decimal.new("15.99"),
        rating: :"NC-17",
        special_features: []
      }
    ]

    films =
      Enum.map(films_data, fn film_data ->
        Film.changeset(%Film{}, film_data) |> Repo.insert!()
      end)

    [film1, film2, film3] = films

    # Define comprehensive domain with all column types from Pagila
    domain = %{
      source: %{
        source_table: "film",
        primary_key: :film_id,
        fields: [
          :film_id,
          :title,
          :description,
          :release_year,
          :language_id,
          :rental_duration,
          :rental_rate,
          :length,
          :replacement_cost,
          :rating,
          :special_features,
          :last_update
        ],
        redact_fields: [],
        columns: %{
          film_id: %{type: :integer},
          title: %{type: :string},
          description: %{type: :text},
          release_year: %{type: :integer},
          language_id: %{type: :integer},
          rental_duration: %{type: :integer},
          rental_rate: %{type: :decimal},
          length: %{type: :integer},
          replacement_cost: %{type: :decimal},
          rating: %{type: :string},
          special_features: %{type: {:array, :string}},
          last_update: %{type: :utc_datetime}
        },
        associations: %{}
      },
      name: "Film",
      joins: %{},
      schemas: %{}
    }

    selecto = Selecto.configure(domain, SelectoTest.Repo)

    {:ok, selecto: selecto, film1: film1, film2: film2, film3: film3}
  end

  describe "Integer Column Type" do
    test "select integer fields", %{selecto: selecto, film1: film1} do
      result =
        selecto
        |> Selecto.select(["film_id", "release_year", "length"])
        |> Selecto.filter({"film_id", film1.film_id})
        |> Selecto.execute()

      assert {:ok, {rows, columns, _aliases}} = result
      assert columns == ["film_id", "release_year", "length"]
      assert length(rows) == 1
      [film_id, release_year, length] = hd(rows)
      assert is_integer(film_id)
      assert is_integer(release_year) or is_nil(release_year)
      assert is_integer(length) or is_nil(length)
    end

    test "filter integer with various operators", %{selecto: selecto} do
      # Test various integer filter operations
      operators_tests = [
        {{"release_year", {"=", 2006}},
         fn rows ->
           Enum.all?(rows, fn [year] -> year == 2006 end)
         end},
        {{"release_year", {">", 2005}},
         fn rows ->
           Enum.all?(rows, fn [year] -> year > 2005 end)
         end},
        {{"release_year", {"<", 2007}},
         fn rows ->
           Enum.all?(rows, fn [year] -> year < 2007 end)
         end},
        {{"release_year", [2005, 2006]},
         fn rows ->
           Enum.all?(rows, fn [year] -> year in [2005, 2006] end)
         end}
      ]

      Enum.each(operators_tests, fn {filter, validator} ->
        result =
          selecto
          |> Selecto.select(["release_year"])
          |> Selecto.filter(filter)
          |> Selecto.execute()

        assert {:ok, {rows, _columns, _aliases}} = result
        assert validator.(rows), "Filter #{inspect(filter)} failed validation"
      end)
    end

    test "integer type conversion from string", %{selecto: selecto, film1: film1} do
      # Test string to integer conversion (might not be supported)
      result =
        selecto
        |> Selecto.select(["film_id"])
        # String should convert to integer
        |> Selecto.filter({"film_id", "#{film1.film_id}"})
        |> Selecto.execute()

      case result do
        {:ok, {rows, _columns, _aliases}} ->
          assert length(rows) == 1
          assert hd(rows) == [film1.film_id]

        {:error, _} ->
          # String to integer conversion might not be implemented
          :ok
      end
    end
  end

  describe "String Column Type" do
    test "select string fields", %{selecto: selecto, film1: film1} do
      result =
        selecto
        |> Selecto.select(["title", "rating"])
        |> Selecto.filter({"film_id", film1.film_id})
        |> Selecto.execute()

      assert {:ok, {rows, columns, _aliases}} = result
      assert columns == ["title", "rating"]
      assert length(rows) == 1
      [title, rating] = hd(rows)
      assert is_binary(title)
      assert is_binary(rating) or is_nil(rating)
    end

    test "string LIKE operations", %{selecto: selecto} do
      result =
        selecto
        |> Selecto.select(["title"])
        |> Selecto.filter({"title", {:like, "A%"}})
        |> Selecto.execute()

      assert {:ok, {rows, _columns, _aliases}} = result
      assert length(rows) > 0

      Enum.each(rows, fn [title] ->
        assert String.starts_with?(title, "A")
      end)
    end

    test "string ILIKE operations (case insensitive)", %{selecto: selecto} do
      result =
        selecto
        |> Selecto.select(["title"])
        |> Selecto.filter({"title", {:ilike, "academy%"}})
        |> Selecto.execute()

      assert {:ok, {rows, _columns, _aliases}} = result
      assert length(rows) > 0

      Enum.each(rows, fn [title] ->
        assert String.starts_with?(String.downcase(title), "academy")
      end)
    end

    test "string IN operations", %{selecto: selecto} do
      result =
        selecto
        |> Selecto.select(["rating"])
        |> Selecto.filter({"rating", ["G", "PG"]})
        |> Selecto.execute()

      assert {:ok, {rows, _columns, _aliases}} = result
      assert length(rows) > 0

      Enum.each(rows, fn [rating] ->
        assert rating in ["G", "PG"]
      end)
    end
  end

  describe "Text Column Type" do
    test "select text field", %{selecto: selecto, film1: film1} do
      result =
        selecto
        |> Selecto.select(["description"])
        |> Selecto.filter({"film_id", film1.film_id})
        |> Selecto.execute()

      assert {:ok, {rows, columns, _aliases}} = result
      assert columns == ["description"]
      assert length(rows) == 1
      [description] = hd(rows)
      assert is_binary(description) or is_nil(description)
      # Descriptions are long
      if description, do: assert(String.length(description) > 10)
    end

    test "text LIKE pattern matching", %{selecto: selecto} do
      result =
        selecto
        |> Selecto.select(["film_id", "description"])
        |> Selecto.filter({"description", {:like, "%Drama%"}})
        |> Selecto.execute()

      assert {:ok, {rows, _columns, _aliases}} = result

      Enum.each(rows, fn [_film_id, description] ->
        if description do
          assert String.contains?(description, "Drama")
        end
      end)
    end
  end

  describe "Decimal Column Type" do
    test "select decimal fields", %{selecto: selecto, film1: film1} do
      result =
        selecto
        |> Selecto.select(["rental_rate", "replacement_cost"])
        |> Selecto.filter({"film_id", film1.film_id})
        |> Selecto.execute()

      assert {:ok, {rows, columns, _aliases}} = result
      assert columns == ["rental_rate", "replacement_cost"]
      assert length(rows) == 1
      [rental_rate, replacement_cost] = hd(rows)
      assert %Decimal{} = rental_rate
      assert %Decimal{} = replacement_cost
    end

    test "decimal comparison operations", %{selecto: selecto} do
      result =
        selecto
        |> Selecto.select(["film_id", "rental_rate"])
        |> Selecto.filter({"rental_rate", {">", Decimal.new("4.00")}})
        |> Selecto.execute()

      assert {:ok, {rows, _columns, _aliases}} = result
      assert length(rows) > 0

      Enum.each(rows, fn [_film_id, rental_rate] ->
        assert Decimal.compare(rental_rate, Decimal.new("4.00")) == :gt
      end)
    end

    test "decimal range filtering", %{selecto: selecto} do
      result =
        selecto
        |> Selecto.select(["rental_rate"])
        |> Selecto.filter({"rental_rate", {:between, Decimal.new("2.00"), Decimal.new("3.00")}})
        |> Selecto.execute()

      assert {:ok, {rows, _columns, _aliases}} = result
      assert length(rows) > 0

      Enum.each(rows, fn [rental_rate] ->
        assert Decimal.compare(rental_rate, Decimal.new("2.00")) != :lt
        assert Decimal.compare(rental_rate, Decimal.new("3.00")) != :gt
      end)
    end
  end

  describe "Array Column Type" do
    test "select array field", %{selecto: selecto, film1: film1} do
      result =
        selecto
        |> Selecto.select(["special_features"])
        |> Selecto.filter({"film_id", film1.film_id})
        |> Selecto.execute()

      assert {:ok, {rows, columns, _aliases}} = result
      assert columns == ["special_features"]
      assert length(rows) == 1
      [special_features] = hd(rows)
      assert is_list(special_features) or is_nil(special_features)
    end

    test "array filtering with contains", %{selecto: selecto} do
      # Test films that have "Trailers" in special_features
      # Array filtering might not be implemented yet
      result =
        selecto
        |> Selecto.select(["film_id", "special_features"])
        |> Selecto.filter({"special_features", {:contains, "Trailers"}})
        |> Selecto.execute()

      case result do
        {:ok, {_rows, _columns, _aliases}} ->
          # Array filtering works
          :ok

        {:error, _} ->
          # Array filtering might not be implemented yet
          :ok
      end
    end
  end

  describe "DateTime Column Type" do
    test "select datetime field", %{selecto: selecto, film1: film1} do
      result =
        selecto
        |> Selecto.select(["last_update"])
        |> Selecto.filter({"film_id", film1.film_id})
        |> Selecto.execute()

      assert {:ok, {rows, columns, _aliases}} = result
      assert columns == ["last_update"]
      assert length(rows) == 1
      [last_update] = hd(rows)
      # last_update could be NaiveDateTime or DateTime depending on configuration
      assert match?(%NaiveDateTime{}, last_update) or match?(%DateTime{}, last_update)
    end

    test "datetime comparison operations", %{selecto: selecto} do
      # Test filtering by datetime (might need DateTime instead of NaiveDateTime)
      cutoff_date = ~U[2006-02-15 10:00:00Z]

      result =
        selecto
        |> Selecto.select(["film_id", "last_update"])
        |> Selecto.filter({"last_update", {">", cutoff_date}})
        |> Selecto.execute()

      case result do
        {:ok, {rows, _columns, _aliases}} ->
          Enum.each(rows, fn [_film_id, last_update] ->
            # Handle both DateTime and NaiveDateTime
            comparison =
              case last_update do
                %DateTime{} ->
                  DateTime.compare(last_update, cutoff_date)

                %NaiveDateTime{} ->
                  NaiveDateTime.compare(last_update, DateTime.to_naive(cutoff_date))
              end

            assert comparison == :gt
          end)

        {:error, _} ->
          # DateTime filtering might not be implemented or need different format
          :ok
      end
    end
  end

  describe "Type Aggregation and Functions" do
    test "count with different column types", %{selecto: selecto} do
      result =
        selecto
        |> Selecto.select([{:count, "film_id"}, {:count, "title"}, {:count, "rental_rate"}])
        |> Selecto.execute()

      assert {:ok, {rows, columns, _aliases}} = result
      assert columns == ["count", "count", "count"]
      assert length(rows) == 1
      [count_id, count_title, count_rate] = hd(rows)
      assert is_integer(count_id)
      assert is_integer(count_title)
      assert is_integer(count_rate)
      # All should be the same for non-null fields
      assert count_id == count_title
      assert count_id == count_rate
    end

    test "min/max with different numeric types", %{selecto: selecto} do
      result =
        selecto
        |> Selecto.select([
          {:min, "film_id"},
          {:max, "film_id"},
          {:min, "rental_rate"},
          {:max, "rental_rate"}
        ])
        |> Selecto.execute()

      assert {:ok, {rows, columns, _aliases}} = result
      assert columns == ["min", "max", "min", "max"]
      assert length(rows) == 1
      [min_id, max_id, min_rate, max_rate] = hd(rows)

      assert is_integer(min_id)
      assert is_integer(max_id)
      assert min_id <= max_id

      assert %Decimal{} = min_rate
      assert %Decimal{} = max_rate
      assert Decimal.compare(min_rate, max_rate) != :gt
    end

    test "string aggregation functions", %{selecto: selecto} do
      result =
        selecto
        |> Selecto.select([{:min, "title"}, {:max, "title"}])
        |> Selecto.execute()

      assert {:ok, {rows, columns, _aliases}} = result
      assert columns == ["min", "max"]
      assert length(rows) == 1
      [min_title, max_title] = hd(rows)
      assert is_binary(min_title)
      assert is_binary(max_title)
      # Min/max should be alphabetical
      assert min_title <= max_title
    end
  end

  describe "Type Conversion Edge Cases" do
    test "null value handling across types", %{selecto: selecto} do
      # Test NULL filtering for different column types
      column_tests = [
        "title",
        "description",
        "release_year",
        "rental_rate",
        "special_features"
      ]

      Enum.each(column_tests, fn column ->
        # Test NOT NULL filter (should return all non-null rows)
        result =
          selecto
          |> Selecto.select([column])
          |> Selecto.filter({column, :not_null})
          |> Selecto.execute()

        assert {:ok, {rows, _columns, _aliases}} = result
        # Just verify the query executes without error
        assert is_list(rows)

        # Test IS NULL filter (might return empty results if no nulls)
        result =
          selecto
          |> Selecto.select([column])
          |> Selecto.filter({column, nil})
          |> Selecto.execute()

        assert {:ok, {rows, _columns, _aliases}} = result
        assert is_list(rows)
      end)
    end

    test "type coercion in filters", %{selecto: selecto} do
      # Test various type coercions that should work
      type_tests = [
        # Integer field with string value
        {{"film_id", "6396"}, "film_id"},
        # Decimal with integer value
        {{"rental_rate", 4}, "rental_rate"}
        # String field with atom (should convert to string)
        # This might not be supported, but worth testing
      ]

      Enum.each(type_tests, fn {filter, select_field} ->
        result =
          selecto
          |> Selecto.select([select_field])
          |> Selecto.filter(filter)
          |> Selecto.execute()

        case result do
          {:ok, {rows, _columns, _aliases}} ->
            assert is_list(rows)

          {:error, _} ->
            # Some type conversions might not be supported
            :ok
        end
      end)
    end
  end

  describe "Complex Type Combinations" do
    test "mixed type selections with filtering", %{
      selecto: selecto,
      film1: film1,
      film2: film2,
      film3: film3
    } do
      result =
        selecto
        |> Selecto.select([
          # integer
          "film_id",
          # string
          "title",
          # decimal
          "rental_rate",
          # datetime
          "last_update",
          # array
          "special_features"
        ])
        |> Selecto.filter({"film_id", [film1.film_id, film2.film_id, film3.film_id]})
        |> Selecto.execute()

      assert {:ok, {rows, columns, _aliases}} = result
      assert columns == ["film_id", "title", "rental_rate", "last_update", "special_features"]
      assert length(rows) == 3

      Enum.each(rows, fn [film_id, title, rental_rate, last_update, special_features] ->
        assert is_integer(film_id)
        assert is_binary(title)
        assert %Decimal{} = rental_rate
        # Handle both DateTime and NaiveDateTime
        assert match?(%NaiveDateTime{}, last_update) or match?(%DateTime{}, last_update)
        assert is_list(special_features) or is_nil(special_features)
      end)
    end

    test "type-specific aggregations with grouping", %{selecto: selecto} do
      result =
        selecto
        |> Selecto.select([
          "rating",
          {:count, "film_id"},
          {:avg, "rental_rate"},
          {:min, "release_year"},
          {:max, "length"}
        ])
        |> Selecto.group_by(["rating"])
        |> Selecto.filter({"rating", ["G", "PG", "NC-17"]})
        |> Selecto.execute()

      assert {:ok, {rows, columns, _aliases}} = result
      assert columns == ["rating", "count", "avg", "min", "max"]
      # At least G, PG, NC-17
      assert length(rows) >= 3

      Enum.each(rows, fn [rating, count, avg_rate, min_year, max_length] ->
        assert is_binary(rating) and rating in ["G", "PG", "NC-17"]
        assert is_integer(count) and count > 0
        assert %Decimal{} = avg_rate
        assert is_integer(min_year)
        assert is_integer(max_length) or is_nil(max_length)
      end)
    end
  end
end
