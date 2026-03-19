defmodule SelectoTest.Seed do
  import Ecto.Query

  alias SelectoTest.Repo
  alias SelectoTest.Store.{Language, Film, Flag}
  alias SelectoTest.SavedView

  def init() do
    # Seed saved views first
    seed_saved_views()

    # Create flags
    Enum.each(["F1", "F2", "F3", "F4"], &insert_or_get_flag/1)

    # Create languages
    english = insert_or_get_language("English")
    _spanish = insert_or_get_language("Spanish")

    # Create films with various data types for column type testing
    [
      %{
        title: "Academy Dinosaur",
        description:
          "A Epic Drama of a Feminist And a Mad Scientist who must Battle a Teacher in The Canadian Rockies",
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
        description:
          "A Astounding Epistle of a Database Administrator And a Explorer who must Find a Car in Ancient China",
        release_year: 2006,
        language_id: english.language_id,
        rental_duration: 3,
        rental_rate: Decimal.new("4.99"),
        length: 48,
        replacement_cost: Decimal.new("12.99"),
        rating: :G,
        special_features: ["Trailers", "Deleted Scenes"]
      },
      %{
        title: "Adaptation Holes",
        description:
          "A Astounding Reflection of a Lumberjack And a Car who must Sink a Lumberjack in A Baloon Factory",
        release_year: 2006,
        language_id: english.language_id,
        rental_duration: 7,
        rental_rate: Decimal.new("2.99"),
        length: 50,
        replacement_cost: Decimal.new("18.99"),
        rating: :"NC-17",
        special_features: ["Trailers", "Commentaries"]
      }
    ]
    |> Enum.each(&insert_or_update_film/1)
  end

  def saved_views do
    film_saved_views() ++ actor_saved_views()
  end

  defp seed_saved_views() do
    saved_views()
    |> Enum.each(&insert_or_update_view/1)
  end

  defp film_saved_views do
    [
      graph_view(
        "Film Ratings Distribution",
        "/pagila_films",
        [{"rating", "rating"}],
        [{"film_id", "count", "film_count"}],
        "bar",
        %{"title" => "Distribution of Films by Rating", "responsive" => true}
      ),
      graph_view(
        "Monthly Rental Revenue",
        "/pagila_films",
        [{"release_year", "release_year"}],
        [{"rental_rate", "sum", "total_revenue"}],
        "line",
        %{"title" => "Rental Revenue by Release Year", "responsive" => true}
      ),
      graph_view(
        "Monty Rental Revenue",
        "/pagila_films",
        [{"rating", "rating"}],
        [
          {"film_id", "count", "film_count"},
          {"length", "avg", "avg_length"},
          {"replacement_cost", "avg", "avg_replacement_cost"}
        ],
        "bar",
        %{"title" => "Film Portfolio by Rating", "responsive" => true}
      ),
      graph_view(
        "Film Length by Category and Rating",
        "/pagila_films",
        [{"rating", "rating"}],
        [
          {"length", "avg", "avg_length", %{"series_type" => "line", "axis" => "right"}},
          {"film_id", "count", "film_count", %{"series_type" => "bar", "axis" => "left"}}
        ],
        "bar",
        %{
          "title" => "Film Count and Avg Length by Rating",
          "y_axis_label" => "Film Count",
          "y2_axis_label" => "Average Length (minutes)",
          "stacked" => false,
          "responsive" => true
        }
      ),
      detail_view(
        "Action Films Detail",
        "/pagila_films",
        [
          {"title", "title"},
          {"release_year", "year"},
          {"rating", "rating"},
          {"rental_rate", "price"},
          {"length", "duration"}
        ],
        order_by: [{"title", "asc"}],
        per_page: 50,
        filters: [{"rating", "=", "PG"}]
      ),
      graph_view(
        "Special Features Distribution",
        "/pagila_films",
        [{"special_features", "feature"}],
        [{"film_id", "count", "count"}],
        "pie",
        %{
          "title" => "Distribution of Special Features",
          "responsive" => true,
          "legend" => %{"position" => "right"}
        }
      ),
      graph_view(
        "Revenue by Rating",
        "/pagila_films",
        [{"rating", "rating"}],
        [{"film_id", "sum", "films"}, {"rental_rate", "sum", "revenue"}],
        "bar",
        %{"title" => "Revenue and Film Count by Rating", "responsive" => true}
      ),
      graph_view(
        "Films by Language",
        "/pagila_films",
        [{"language.name", "language"}],
        [{"film_id", "count", "film_count"}],
        "bar",
        %{"title" => "Number of Films by Language", "responsive" => true}
      ),
      detail_view(
        "Recent Films with Actors",
        "/pagila_films",
        [
          {"title", "title"},
          {"release_year", "year"},
          {"rating", "rating"},
          {"language_id", "language_id"},
          {"rental_rate", "rate"}
        ],
        order_by: [{"release_year", "desc"}, {"title", "asc"}],
        per_page: 25,
        prevent_denormalization: true
      ),
      detail_view(
        "Rating and Cast Explorer",
        "/pagila_films",
        [
          {"title", "film_title"},
          {"rating", "mpaa_rating"},
          {"release_year", "year"},
          {"language_id", "language_id"},
          {"rental_duration", "rental_days"}
        ],
        order_by: [{"rating", "asc"}, {"title", "asc"}],
        per_page: 60
      ),
      graph_view(
        "Rental Metrics Comparison",
        "/pagila_films",
        [{"rental_duration", "rental_days"}],
        [{"rental_rate", "avg", "avg_rate"}, {"replacement_cost", "avg", "avg_cost"}],
        "line",
        %{
          "title" => "Rental Rate vs Replacement Cost by Duration",
          "responsive" => true,
          "scales" => %{"yAxes" => [%{"ticks" => %{"beginAtZero" => true}}]}
        }
      ),
      detail_view(
        "Premium Long Features",
        "/pagila_films",
        [
          {"title", "title"},
          {"rating", "rating"},
          {"length", "minutes"},
          {"rental_rate", "rate"},
          {"replacement_cost", "replacement_cost"}
        ],
        order_by: [{"rental_rate", "desc"}, {"length", "desc"}, {"title", "asc"}],
        per_page: 40,
        filters: [{"rental_rate", ">=", "3.99"}, {"length", ">=", "120"}]
      )
    ]
  end

  defp actor_saved_views do
    [
      aggregate_view(
        "Actor Performance Metrics",
        "/pagila",
        [{"first_name", "first_name"}, {"last_name", "last_name"}],
        [
          {"actor_id", "count", "film_count"},
          {"film.release_year", "max", "latest_release_year"}
        ],
        order_by: [{"film_count", "desc"}]
      ),
      detail_view(
        "Actor Directory",
        "/pagila",
        [{"actor_id", "actor_id"}, {"first_name", "first_name"}, {"last_name", "last_name"}],
        order_by: [{"last_name", "asc"}, {"first_name", "asc"}],
        per_page: 75
      ),
      detail_view(
        "Actor Filmography Snapshot",
        "/pagila",
        [
          {"full_name", "actor"},
          {"film.title", "film_title"},
          {"film.release_year", "release_year"},
          {"film.rating", "rating"},
          {"film.length", "minutes"}
        ],
        order_by: [{"film.release_year", "desc"}, {"full_name", "asc"}],
        per_page: 50
      ),
      aggregate_view(
        "Top Cast by Film Count",
        "/pagila",
        [{"full_name", "actor"}],
        [{"actor_id", "count", "film_count"}, {"film.length", "avg", "avg_length"}],
        order_by: [{"film_count", "desc"}, {"avg_length", "desc"}]
      ),
      graph_view(
        "Actor Rating Spread",
        "/pagila",
        [{"film.rating", "rating"}],
        [{"actor_id", "count", "appearance_count"}],
        "bar",
        %{"title" => "Actor Appearances by Film Rating", "responsive" => true}
      ),
      aggregate_view(
        "Release Year Coverage",
        "/pagila",
        [{"full_name", "actor"}],
        [
          {"film.release_year", "min", "first_release_year"},
          {"film.release_year", "max", "latest_release_year"},
          {"actor_id", "count", "film_count"}
        ],
        order_by: [{"latest_release_year", "desc"}, {"film_count", "desc"}]
      ),
      detail_view(
        "Premium Catalog Cast",
        "/pagila",
        [
          {"full_name", "actor"},
          {"film.title", "film_title"},
          {"film.rating", "rating"},
          {"film.rental_rate", "rate"},
          {"film.replacement_cost", "replacement_cost"}
        ],
        order_by: [{"film.rental_rate", "desc"}, {"full_name", "asc"}],
        per_page: 40,
        filters: [{"film.rental_rate", ">=", "4.99"}]
      ),
      aggregate_view(
        "Long Feature Specialists",
        "/pagila",
        [{"full_name", "actor"}],
        [{"actor_id", "count", "film_count"}, {"film.length", "avg", "avg_length"}],
        order_by: [{"avg_length", "desc"}, {"film_count", "desc"}],
        filters: [{"film.length", ">=", "120"}]
      ),
      aggregate_view(
        "Family Name Leaderboard",
        "/pagila",
        [{"last_name", "last_name"}],
        [{"actor_id", "count", "actor_count"}],
        order_by: [{"actor_count", "desc"}, {"last_name", "asc"}]
      ),
      graph_view(
        "Recent Release Ensembles",
        "/pagila",
        [{"film.release_year", "release_year"}],
        [{"actor_id", "count", "appearance_count"}, {"film.rental_rate", "avg", "avg_rate"}],
        "line",
        %{"title" => "Actor Appearances and Avg Rate by Release Year", "responsive" => true}
      ),
      detail_view(
        "NC-17 Specialists",
        "/pagila",
        [
          {"full_name", "actor"},
          {"film.title", "film_title"},
          {"film.release_year", "release_year"},
          {"film.rating", "rating"}
        ],
        order_by: [{"full_name", "asc"}, {"film.title", "asc"}],
        per_page: 40,
        filters: [{"film.rating", "=", "NC-17"}]
      ),
      aggregate_view(
        "Replacement Cost Exposure",
        "/pagila",
        [{"full_name", "actor"}],
        [
          {"film.replacement_cost", "sum", "replacement_value"},
          {"film.rental_rate", "avg", "avg_rate"},
          {"actor_id", "count", "film_count"}
        ],
        order_by: [{"replacement_value", "desc"}, {"film_count", "desc"}]
      )
    ]
  end

  defp detail_view(name, context, selected, opts) do
    params =
      %{
        "view_mode" => "detail",
        "selected" => indexed_fields(selected),
        "order_by" => indexed_order_by(Keyword.get(opts, :order_by, [])),
        "per_page" => to_string(Keyword.get(opts, :per_page, 50)),
        "prevent_denormalization" => Keyword.get(opts, :prevent_denormalization, false)
      }
      |> maybe_put_entries("filters", Keyword.get(opts, :filters, []), &indexed_filters/1)

    %{name: name, context: context, params: params}
  end

  defp aggregate_view(name, context, group_by, aggregates, opts) do
    params =
      %{
        "view_mode" => "aggregate",
        "group_by" => indexed_fields(group_by),
        "aggregates" => indexed_metrics(aggregates)
      }
      |> maybe_put_entries("order_by", Keyword.get(opts, :order_by, []), &indexed_order_by/1)
      |> maybe_put_entries("filters", Keyword.get(opts, :filters, []), &indexed_filters/1)

    %{name: name, context: context, params: params}
  end

  defp graph_view(name, context, x_axis, y_axis, chart_type, options, opts \\ []) do
    params =
      %{
        "view_mode" => "graph",
        "x_axis" => indexed_fields(x_axis),
        "y_axis" => indexed_metrics(y_axis),
        "chart_type" => chart_type,
        "options" => options
      }
      |> maybe_put_entries("filters", Keyword.get(opts, :filters, []), &indexed_filters/1)

    %{name: name, context: context, params: params}
  end

  defp maybe_put_entries(params, _key, [], _builder), do: params

  defp maybe_put_entries(params, key, entries, builder) do
    Map.put(params, key, builder.(entries))
  end

  defp indexed_fields(entries) do
    indexed_entries(entries, fn entry, index ->
      {field, alias_name} = normalize_field_entry(entry)

      %{"field" => field, "index" => index, "alias" => alias_name}
    end)
  end

  defp indexed_order_by(entries) do
    indexed_entries(entries, fn {field, dir}, index ->
      %{"field" => field, "dir" => dir, "index" => index}
    end)
  end

  defp indexed_filters(entries) do
    indexed_entries(entries, fn {filter, comp, value}, index ->
      %{"filter" => filter, "comp" => comp, "value" => value, "index" => index}
    end)
  end

  defp indexed_metrics(entries) do
    indexed_entries(entries, fn entry, index ->
      {field, function, alias_name, extra} = normalize_metric_entry(entry)

      %{"field" => field, "function" => function, "index" => index, "alias" => alias_name}
      |> Map.merge(extra)
    end)
  end

  defp indexed_entries(entries, builder) do
    entries
    |> Enum.with_index()
    |> Map.new(fn {entry, index} ->
      string_index = Integer.to_string(index)
      {string_index, builder.(entry, string_index)}
    end)
  end

  defp normalize_field_entry({field, alias_name}), do: {field, alias_name}
  defp normalize_field_entry(field) when is_binary(field), do: {field, field}

  defp normalize_metric_entry({field, function, alias_name}),
    do: {field, function, alias_name, %{}}

  defp normalize_metric_entry({field, function, alias_name, extra}),
    do: {field, function, alias_name, extra}

  defp insert_or_update_view(attrs) do
    case Repo.get_by(SavedView, name: attrs.name, context: attrs.context) do
      nil ->
        %SavedView{}
        |> SavedView.changeset(attrs)
        |> Repo.insert!()

      existing ->
        existing
        |> SavedView.changeset(attrs)
        |> Repo.update!()
    end
  end

  defp insert_or_get_flag(name) do
    dedupe_flags(name)

    case first_by(Flag, :name, name, :id) do
      nil -> Repo.insert!(%Flag{name: name})
      existing -> existing
    end
  end

  defp insert_or_get_language(name) do
    case first_by(Language, :name, name, :language_id) do
      nil ->
        %Language{}
        |> Language.changeset(%{name: name})
        |> Repo.insert!()

      existing ->
        existing
    end
  end

  defp insert_or_update_film(attrs) do
    case first_by(Film, :title, attrs.title, :film_id) do
      nil ->
        %Film{}
        |> Film.changeset(attrs)
        |> Repo.insert!()

      existing ->
        existing
        |> Film.changeset(attrs)
        |> Repo.update!()
    end
  end

  defp first_by(schema, field, value, order_field) do
    schema
    |> where([row], field(row, ^field) == ^value)
    |> order_by([row], asc: field(row, ^order_field))
    |> limit(1)
    |> Repo.one()
  end

  defp dedupe_flags(name) do
    ids_to_delete =
      Flag
      |> where([flag], flag.name == ^name)
      |> order_by([flag], asc: flag.id)
      |> offset(1)
      |> select([flag], flag.id)
      |> Repo.all()

    case ids_to_delete do
      [] -> :ok
      ids -> Repo.delete_all(from(flag in Flag, where: flag.id in ^ids))
    end
  end
end
