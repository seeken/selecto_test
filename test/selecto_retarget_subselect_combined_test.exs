defmodule SelectoRetargetSubselectCombinedTest do
  use SelectoTest.SelectoCase, async: false

  alias SelectoTest.PagilaData

  # Subselects added after a retarget correlate with the target rows and
  # resolve from the target relation: retargeting a film to its cast lets each
  # actor carry their own filmography.

  setup_all do
    PagilaData.ensure_loaded!()
  end

  describe "Combined Retarget and Subselect features" do
    test "retarget a film to its cast with each actor's film count" do
      query =
        films()
        |> Selecto.filter({"title", "ACADEMY DINOSAUR"})
        |> Selecto.retarget("film_actors.actor")
        |> Selecto.select(["actor_id", "first_name", "last_name"])
        |> Selecto.subselect([
          %{fields: ["film_id"], target_schema: :film_actors, format: :count, alias: "film_count"}
        ])
        |> Selecto.order_by(["actor_id"])

      {:ok, {rows, columns, _aliases}} = Selecto.execute(query)
      assert columns == ["actor_id", "first_name", "last_name", "film_count"]

      expected =
        PagilaData.rows!("""
        select a.actor_id, a.first_name, a.last_name,
               (select count(*) from film_actor own where own.actor_id = a.actor_id)
        from actor a
        where a.actor_id in (
          select fa.actor_id
          from film f
          join film_actor fa on fa.film_id = f.film_id
          where f.title = 'ACADEMY DINOSAUR')
        order by a.actor_id
        """)

      assert length(expected) > 1
      assert rows == expected
    end

    test "retarget with multiple subselects using different aggregation formats" do
      rows =
        films()
        |> Selecto.filter({"title", "ACE GOLDFINGER"})
        |> Selecto.retarget("film_actors.actor")
        |> Selecto.select(["actor_id"])
        |> Selecto.subselect([
          %{
            fields: ["film_id"],
            target_schema: :film_actors,
            format: :json_agg,
            alias: "film_ids",
            order_by: [:film_id]
          },
          %{
            fields: ["film_id"],
            target_schema: :film_actors,
            format: :array_agg,
            alias: "film_id_array"
          },
          %{fields: ["film_id"], target_schema: :film_actors, format: :count, alias: "film_count"}
        ])
        |> Selecto.order_by(["actor_id"])
        |> rows!()

      expected =
        PagilaData.rows!("""
        select fa.actor_id, array_agg(own.film_id order by own.film_id)
        from film f
        join film_actor fa on fa.film_id = f.film_id
        join film_actor own on own.actor_id = fa.actor_id
        where f.title = 'ACE GOLDFINGER'
        group by fa.actor_id
        order by fa.actor_id
        """)

      assert expected != []

      # json_agg follows the subselect ordering; array_agg is compared as a set.
      assert Enum.map(rows, fn [actor_id, json_ids, array_ids, count] ->
               [actor_id, json_ids, Enum.sort(array_ids), count]
             end) ==
               Enum.map(expected, fn [actor_id, film_ids] ->
                 [actor_id, film_ids, film_ids, length(film_ids)]
               end)
    end

    test "retarget with filtered and ordered subselects through the junction" do
      rows =
        filmography()
        |> Selecto.filter({"title", "ACE GOLDFINGER"})
        |> Selecto.retarget("film_actors.actor")
        |> Selecto.select(["actor_id"])
        |> Selecto.subselect([
          %{
            fields: ["title", "rating"],
            target_schema: :film,
            format: :json_agg,
            alias: "r_rated_films",
            filters: [{"rating", "R"}],
            order_by: [:title]
          }
        ])
        |> Selecto.order_by(["actor_id"])
        |> rows!()

      expected =
        PagilaData.rows!("""
        select fa.actor_id,
               (select array_agg(other.title order by other.title)
                from film other
                join film_actor own on own.film_id = other.film_id
                where own.actor_id = fa.actor_id and other.rating = 'R')
        from film f
        join film_actor fa on fa.film_id = f.film_id
        where f.title = 'ACE GOLDFINGER'
        order by fa.actor_id
        """)

      assert Enum.any?(expected, fn [_actor_id, titles] -> titles != nil end)

      assert Enum.all?(rows, fn [_actor_id, films] ->
               Enum.all?(films || [], &(&1["rating"] == "R"))
             end)

      assert Enum.map(rows, fn [actor_id, films] ->
               [actor_id, films && Enum.map(films, & &1["title"])]
             end) == expected
    end

    test "a target filter after the retarget narrows the films that get subselects" do
      rows =
        actors()
        |> Selecto.filter([{"first_name", "JULIA"}, {"last_name", "MCQUEEN"}])
        |> Selecto.retarget(:film)
        |> Selecto.filter({"rating", "PG"})
        |> Selecto.select(["title", "rating"])
        |> Selecto.subselect([
          %{
            fields: ["name"],
            target_schema: :language,
            format: :string_agg,
            alias: "language",
            separator: ", "
          }
        ])
        |> Selecto.order_by(["title"])
        |> rows!()

      expected =
        PagilaData.rows!("""
        select f.title, f.rating, l.name::text
        from film f
        join language l on l.language_id = f.language_id
        join film_actor fa on fa.film_id = f.film_id
        join actor a on a.actor_id = fa.actor_id
        where a.first_name = 'JULIA' and a.last_name = 'MCQUEEN' and f.rating = 'PG'
        order by f.title
        """)

      assert expected != []
      assert rows == expected
    end

    test "retarget with exists strategy and subselects" do
      cast = fn opts ->
        films()
        |> Selecto.filter({"rating", "NC-17"})
        |> Selecto.filter({"length", {:gt, 180}})
        |> Selecto.retarget("film_actors.actor", opts)
        |> Selecto.select(["actor_id"])
        |> Selecto.subselect([
          %{fields: ["film_id"], target_schema: :film_actors, format: :count, alias: "film_count"}
        ])
        |> Selecto.order_by(["actor_id"])
      end

      exists_query = cast.(strategy: :exists)
      {sql, _params} = Selecto.to_sql(exists_query)
      assert sql =~ ~r/\bexists\s*\(/i

      expected =
        PagilaData.rows!("""
        select a.actor_id,
               (select count(*) from film_actor own where own.actor_id = a.actor_id)
        from actor a
        where a.actor_id in (
          select fa.actor_id
          from film f
          join film_actor fa on fa.film_id = f.film_id
          where f.rating = 'NC-17' and f.length > 180)
        order by a.actor_id
        """)

      assert expected != []
      assert rows!(cast.([])) == expected
      assert rows!(exists_query) == expected
    end
  end

  describe "SQL generation for combined features" do
    test "the subselect correlates with the target root, not the context" do
      {sql, params} =
        films()
        |> Selecto.filter({"title", "ACADEMY DINOSAUR"})
        |> Selecto.retarget("film_actors.actor")
        |> Selecto.select(["actor_id"])
        |> Selecto.subselect([
          %{fields: ["film_id"], target_schema: :film_actors, format: :count, alias: "film_count"}
        ])
        |> Selecto.to_sql()

      assert sql =~ ~r/from actor selecto_root/i

      assert sql =~
               ~r/from film_actor sub_film_actors where sub_film_actors\."actor_id" = selecto_root\."actor_id"/i

      assert sql =~ ~r/selecto_root\.actor_id in \(\s*select actor\.actor_id\s+from film/i
      assert params == ["ACADEMY DINOSAUR"]
    end
  end

  describe "Error handling in combined scenarios" do
    test "invalid retarget target with subselects" do
      error =
        assert_raise Selecto.Retarget.Error, fn ->
          actors()
          |> Selecto.retarget(:invalid_schema)
          |> Selecto.subselect(["film.title"])
        end

      assert error.code == :unknown_association
    end

    test "invalid subselect target with retarget" do
      assert_raise ArgumentError, ~r/Target schema.*not found/, fn ->
        actors()
        |> Selecto.retarget(:film)
        |> Selecto.subselect(["invalid_schema.field"])
      end
    end

    test "a relation reached only from the original root is not a subselect target" do
      # The actor domain reaches film_actors from the actor; a film does not.
      assert_raise ArgumentError, ~r/Cannot reach target schema/, fn ->
        actors()
        |> Selecto.retarget(:film)
        |> Selecto.subselect([
          %{fields: ["actor_id"], target_schema: :film_actors, format: :count, alias: "cast"}
        ])
      end
    end
  end

  defp actors, do: configure(SelectoTest.PagilaDomain.actors_domain())

  defp films, do: configure(SelectoTest.PagilaDomainFilms.films_domain())

  # The film domain with a film schema the junction can reach, so a film's
  # cast can subselect the films each actor appears in.
  defp filmography do
    domain = SelectoTest.PagilaDomainFilms.films_domain()

    film =
      domain.source
      |> Map.take([:source_table, :primary_key, :fields, :redact_fields, :columns])
      |> Map.put(:associations, %{})

    domain
    |> put_in([:schemas, :film], film)
    |> put_in([:schemas, :film_actors, :associations, :film], %{
      queryable: :film,
      field: :film,
      owner_key: :film_id,
      related_key: :film_id
    })
    |> configure()
  end

  defp configure(domain), do: Selecto.configure(domain, SelectoTest.Repo, validate: false)

  defp rows!(query) do
    case Selecto.execute(query) do
      {:ok, {rows, _columns, _aliases}} -> rows
      {:error, error} -> flunk("query failed: #{inspect(error)}")
    end
  end
end
