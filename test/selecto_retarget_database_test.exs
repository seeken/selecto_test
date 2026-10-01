defmodule SelectoRetargetDatabaseTest do
  use SelectoTest.SelectoCase, async: false

  alias Selecto.Retarget
  alias SelectoTest.PagilaData

  # A retarget moves the row grain from the domain root to the relation at a
  # join path. The filters applied before it become the context, and the
  # result is the distinct target rows the original joined read reaches. Each
  # test asks Pagila the same question in plain SQL and compares the rows.

  setup_all do
    PagilaData.ensure_loaded!()
  end

  describe "Actor domain retargeted to films" do
    test "a join id retargets to the films of the filtered actor" do
      query =
        actors()
        |> Selecto.filter([{"first_name", "PENELOPE"}, {"last_name", "GUINESS"}])
        |> Selecto.retarget(:film)
        |> Selecto.select(["film_id", "title", "rating"])
        |> Selecto.order_by(["film_id"])

      expected =
        PagilaData.rows!("""
        select f.film_id, f.title, f.rating
        from film f
        join film_actor fa on fa.film_id = f.film_id
        join actor a on a.actor_id = fa.actor_id
        where a.first_name = 'PENELOPE' and a.last_name = 'GUINESS'
        order by f.film_id
        """)

      assert expected != []
      assert rows!(query) == expected

      {sql, params} = Selecto.to_sql(query)
      assert sql =~ ~r/from film selecto_root/i
      assert sql =~ ~r/selecto_root\.film_id in \(\s*select film\.film_id\s+from actor/i
      assert params == ["PENELOPE", "GUINESS"]
    end

    test "a dotted join path names the same target as its join id" do
      context = actors() |> Selecto.filter({"actor_id", 1})
      by_id = Selecto.retarget(context, :film)
      by_path = Selecto.retarget(context, "film_actors.film")

      assert %{
               path: "film_actors.film",
               join: :film,
               target_schema: :film,
               primary_key: :film_id,
               strategy: :in
             } = Retarget.get_retarget_config(by_path)

      assert Retarget.get_retarget_config(by_id) == Retarget.get_retarget_config(by_path)

      film_ids = fn query ->
        query |> Selecto.select(["film_id"]) |> Selecto.order_by(["film_id"]) |> rows!()
      end

      expected =
        PagilaData.rows!("select film_id from film_actor where actor_id = 1 order by film_id")

      assert expected != []
      assert film_ids.(by_id) == expected
      assert film_ids.(by_path) == expected
    end

    test "each film appears once however many filtered actors reach it" do
      films =
        actors()
        |> Selecto.filter({"first_name", "PENELOPE"})
        |> Selecto.retarget(:film)
        |> Selecto.select(["film_id"])
        |> Selecto.order_by(["film_id"])
        |> rows!()

      expected =
        PagilaData.rows!("""
        select distinct fa.film_id
        from actor a
        join film_actor fa on fa.actor_id = a.actor_id
        where a.first_name = 'PENELOPE'
        order by fa.film_id
        """)

      [[actor_film_pairs]] =
        PagilaData.rows!("""
        select count(*)
        from actor a
        join film_actor fa on fa.actor_id = a.actor_id
        where a.first_name = 'PENELOPE'
        """)

      # Several PENELOPEs share films, so the joined read repeats some of them.
      assert actor_film_pairs > length(expected)
      assert films == expected
    end

    test "the exists strategy returns the same films as the in strategy" do
      context = actors() |> Selecto.filter({"last_name", "WAHLBERG"})

      films = fn opts ->
        context
        |> Selecto.retarget(:film, opts)
        |> Selecto.select(["film_id", "title"])
        |> Selecto.order_by(["film_id"])
      end

      exists_query = films.(strategy: :exists)
      assert Retarget.get_retarget_config(exists_query).strategy == :exists

      {sql, _params} = Selecto.to_sql(exists_query)
      assert sql =~ ~r/\bexists\s*\(/i
      refute sql =~ ~r/selecto_root\.film_id in \(/i

      expected =
        PagilaData.rows!("""
        select distinct f.film_id, f.title
        from actor a
        join film_actor fa on fa.actor_id = a.actor_id
        join film f on f.film_id = fa.film_id
        where a.last_name = 'WAHLBERG'
        order by f.film_id
        """)

      assert expected != []
      assert rows!(films.([])) == expected
      assert rows!(exists_query) == expected
    end

    test "or and comparison filters in the context select the films they describe" do
      films =
        actors()
        |> Selecto.filter([
          {:or, [{"last_name", "GUINESS"}, {"film.title", "ACE GOLDFINGER"}]},
          {"actor_id", {:lt, 100}}
        ])
        |> Selecto.retarget(:film)
        |> Selecto.select(["film_id"])
        |> Selecto.order_by(["film_id"])
        |> rows!()

      expected =
        PagilaData.rows!("""
        select distinct f.film_id
        from actor a
        join film_actor fa on fa.actor_id = a.actor_id
        join film f on f.film_id = fa.film_id
        where (a.last_name = 'GUINESS' or f.title = 'ACE GOLDFINGER') and a.actor_id < 100
        order by f.film_id
        """)

      [[ace_goldfinger]] =
        PagilaData.rows!("select film_id from film where title = 'ACE GOLDFINGER'")

      assert [ace_goldfinger] in expected
      assert films == expected
    end

    test "a context filter on a join of the path constrains that join's rows" do
      # The GUINESS actors' G-rated films, not every film of an actor who has one.
      films =
        actors()
        |> Selecto.filter([{"last_name", "GUINESS"}, {"film.rating", "G"}])
        |> Selecto.retarget(:film)
        |> Selecto.select(["film_id", "rating"])
        |> Selecto.order_by(["film_id"])
        |> rows!()

      expected =
        PagilaData.rows!("""
        select distinct f.film_id, f.rating
        from actor a
        join film_actor fa on fa.actor_id = a.actor_id
        join film f on f.film_id = fa.film_id
        where a.last_name = 'GUINESS' and f.rating = 'G'
        order by f.film_id
        """)

      assert expected != []
      assert films == expected
      assert Enum.all?(films, fn [_film_id, rating] -> rating == "G" end)
    end
  end

  describe "Filters, ordering, grouping, and joins after a retarget" do
    test "target filters, ordering, and limit apply to the films" do
      films =
        actors()
        |> Selecto.filter({"first_name", "PENELOPE"})
        |> Selecto.retarget(:film)
        |> Selecto.filter({"length", {:gt, 150}})
        |> Selecto.select(["title", "length"])
        |> Selecto.order_by([{:desc, "length"}, "title"])
        |> Selecto.limit(5)
        |> rows!()

      expected =
        PagilaData.rows!("""
        select f.title, f.length
        from film f
        where f.length > 150
          and f.film_id in (
            select fa.film_id
            from actor a
            join film_actor fa on fa.actor_id = a.actor_id
            where a.first_name = 'PENELOPE')
        order by f.length desc, f.title
        limit 5
        """)

      assert length(expected) == 5
      assert films == expected
    end

    test "grouping counts each film once" do
      by_rating =
        actors()
        |> Selecto.filter({"first_name", "PENELOPE"})
        |> Selecto.retarget(:film)
        |> Selecto.select(["rating", {:count, "film_id"}])
        |> Selecto.group_by(["rating"])
        |> Selecto.order_by(["rating"])
        |> rows!()

      expected =
        PagilaData.rows!("""
        select f.rating, count(*)
        from film f
        where f.film_id in (
          select fa.film_id
          from actor a
          join film_actor fa on fa.actor_id = a.actor_id
          where a.first_name = 'PENELOPE')
        group by f.rating
        order by f.rating
        """)

      assert expected != []
      assert by_rating == expected
    end

    test "fields resolve against the film and its own joins" do
      retargeted = actors() |> Selecto.filter({"actor_id", 1}) |> Selecto.retarget(:film)

      films =
        retargeted
        |> Selecto.select(["title", "language.name"])
        |> Selecto.order_by(["title"])
        |> rows!()

      expected =
        PagilaData.rows!("""
        select f.title, l.name
        from film f
        join language l on l.language_id = f.language_id
        join film_actor fa on fa.film_id = f.film_id
        where fa.actor_id = 1
        order by f.title
        """)

      assert expected != []
      assert films == expected

      # Names qualified by the actor domain's film join no longer resolve.
      assert_raise ArgumentError, ~r/Join 'film' not found/, fn ->
        retargeted |> Selecto.select(["film.title"]) |> Selecto.to_sql()
      end
    end
  end

  describe "Film domain retargeted to actors" do
    test "one path through the junction replaces chained retargets" do
      cast =
        films()
        |> Selecto.filter({"rating", "PG"})
        |> Selecto.retarget("film_actors.actor")
        |> Selecto.select(["actor_id", "first_name", "last_name"])
        |> Selecto.order_by([{:desc, "actor_id"}])
        |> rows!()

      expected =
        PagilaData.rows!("""
        select distinct a.actor_id, a.first_name, a.last_name
        from film f
        join film_actor fa on fa.film_id = f.film_id
        join actor a on a.actor_id = fa.actor_id
        where f.rating = 'PG'
        order by a.actor_id desc
        """)

      assert expected != []
      assert cast == expected
    end

    test "a retargeted query cannot be retargeted again" do
      retargeted = films() |> Selecto.retarget("film_actors.actor")

      assert retarget_error(fn -> Selecto.retarget(retargeted, :film_actors) end) ==
               :invalid_query
    end

    test "a filter on the path's target join picks those actors" do
      cast = fn filters ->
        films()
        |> Selecto.filter(filters)
        |> Selecto.retarget("film_actors.actor")
        |> Selecto.select(["actor_id", "first_name", "last_name"])
        |> Selecto.order_by(["actor_id"])
        |> rows!()
      end

      whole_cast = cast.([{"title", "ACADEMY DINOSAUR"}])

      expected =
        PagilaData.rows!("""
        select a.actor_id, a.first_name, a.last_name
        from film f
        join film_actor fa on fa.film_id = f.film_id
        join actor a on a.actor_id = fa.actor_id
        where f.title = 'ACADEMY DINOSAUR'
        order by a.actor_id
        """)

      assert length(expected) > 1
      assert whole_cast == expected

      assert cast.([{"title", "ACADEMY DINOSAUR"}, {"actor.first_name", "PENELOPE"}]) ==
               Enum.filter(whole_cast, fn [_id, first_name, _last_name] ->
                 first_name == "PENELOPE"
               end)
    end
  end

  describe "Context and target filters" do
    test "pre_retarget_filter adds to the context and post_retarget_filter filters the films" do
      retargeted =
        actors()
        |> Selecto.retarget(:film)
        |> Selecto.pre_retarget_filter({"actor_id", 1})
        |> Selecto.post_retarget_filter({"rating", "PG"})

      assert Selecto.pre_retarget_filters(retargeted) == [{"actor_id", 1}]
      assert Selecto.post_retarget_filters(retargeted) == [{"rating", "PG"}]

      films =
        retargeted
        |> Selecto.select(["film_id", "rating"])
        |> Selecto.order_by(["film_id"])
        |> rows!()

      expected =
        PagilaData.rows!("""
        select f.film_id, f.rating
        from film f
        join film_actor fa on fa.film_id = f.film_id
        where fa.actor_id = 1 and f.rating = 'PG'
        order by f.film_id
        """)

      assert expected != []
      assert films == expected
    end

    test "required domain filters always stay in the context" do
      films =
        SelectoTest.PagilaDomain.actors_domain()
        |> Map.put(:required_filters, [{"last_name", "GUINESS"}])
        |> configure()
        |> Selecto.retarget(:film)
        |> Selecto.select(["film_id"])
        |> Selecto.order_by(["film_id"])
        |> rows!()

      expected =
        PagilaData.rows!("""
        select distinct fa.film_id
        from actor a
        join film_actor fa on fa.actor_id = a.actor_id
        where a.last_name = 'GUINESS'
        order by fa.film_id
        """)

      [[all_films]] = PagilaData.rows!("select count(*) from film")

      assert expected != []
      assert length(expected) < all_films
      assert films == expected
    end

    test "reset_retarget returns the actor query" do
      origin =
        actors()
        |> Selecto.filter({"actor_id", 1})
        |> Selecto.select(["first_name", "last_name"])

      retargeted = Selecto.retarget(origin, :film)
      assert Retarget.has_retarget?(retargeted)

      reset = Retarget.reset_retarget(retargeted)
      refute Retarget.has_retarget?(reset)
      assert reset == origin

      assert rows!(reset) ==
               PagilaData.rows!("select first_name, last_name from actor where actor_id = 1")
    end

    test "target filters need a retarget, and a retargeted query's filters cannot scope writes" do
      assert_raise ArgumentError, ~r/requires a retargeted query/, fn ->
        Selecto.post_retarget_filter(actors(), {"rating", "PG"})
      end

      retargeted = actors() |> Selecto.filter({"actor_id", 1}) |> Selecto.retarget(:film)

      assert_raise ArgumentError, ~r/retarget context/, fn ->
        Selecto.query_filters(retargeted)
      end
    end
  end

  describe "Rejected retargets" do
    test "removed options, unknown strategies, and unknown targets raise Selecto.Retarget.Error" do
      context = actors() |> Selecto.filter({"actor_id", 1})

      assert retarget_error(fn ->
               Selecto.retarget(context, :film, subquery_strategy: :exists)
             end) ==
               :invalid_query

      assert retarget_error(fn -> Selecto.retarget(context, :film, preserve_filters: false) end) ==
               :invalid_query

      assert retarget_error(fn -> Selecto.retarget(context, :film, strategy: :join) end) ==
               :invalid_query

      assert retarget_error(fn -> Selecto.retarget(context, :invalid_schema) end) ==
               :unknown_association

      # A dotted path must follow the join tree from the root.
      assert retarget_error(fn -> Selecto.retarget(context, "film.film_actors") end) ==
               :unknown_association
    end
  end

  defp actors, do: configure(SelectoTest.PagilaDomain.actors_domain())

  defp films, do: configure(SelectoTest.PagilaDomainFilms.films_domain())

  defp configure(domain), do: Selecto.configure(domain, SelectoTest.Repo, validate: false)

  defp rows!(query) do
    case Selecto.execute(query) do
      {:ok, {rows, _columns, _aliases}} -> rows
      {:error, error} -> flunk("query failed: #{inspect(error)}")
    end
  end

  defp retarget_error(fun) do
    error = assert_raise Retarget.Error, fun
    error.code
  end
end
