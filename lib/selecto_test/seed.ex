defmodule SelectoTest.Seed do
  alias SelectoTest.Repo
  alias SelectoTest.Store.{Language, Film, Flag}
  alias SelectoTest.SavedView

  def init() do
    # Seed saved views first
    seed_saved_views()
    # Create flags
    Repo.insert!(%Flag{name: "F1"})
    Repo.insert!(%Flag{name: "F2"})
    Repo.insert!(%Flag{name: "F3"})
    Repo.insert!(%Flag{name: "F4"})

    # Create languages
    english = Repo.insert!(%Language{name: "English"})
    _spanish = Repo.insert!(%Language{name: "Spanish"})

    # Create films with various data types for column type testing
    Repo.insert!(
      Film.changeset(%Film{}, %{
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
      })
    )

    Repo.insert!(
      Film.changeset(%Film{}, %{
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
      })
    )

    Repo.insert!(
      Film.changeset(%Film{}, %{
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
      })
    )
  end

  defp seed_saved_views() do
    # Graph View: Film Ratings Distribution
    insert_or_update_view(%{
      name: "Film Ratings Distribution",
      context: "/pagila_films",
      params: %{
        "view_mode" => "graph",
        "x_axis" => %{
          "0" => %{"field" => "rating", "index" => "0", "alias" => "rating"}
        },
        "y_axis" => %{
          "0" => %{
            "field" => "film_id",
            "function" => "count",
            "index" => "0",
            "alias" => "film_count"
          }
        },
        "chart_type" => "bar",
        "options" => %{
          "title" => "Distribution of Films by Rating",
          "responsive" => true
        }
      }
    })

    # Graph View: Rental Revenue by Month
    insert_or_update_view(%{
      name: "Monthly Rental Revenue",
      context: "/pagila_films",
      params: %{
        "view_mode" => "graph",
        "x_axis" => %{
          "0" => %{
            "field" => "release_year",
            "index" => "0",
            "alias" => "release_year"
          }
        },
        "y_axis" => %{
          "0" => %{
            "field" => "rental_rate",
            "function" => "sum",
            "index" => "0",
            "alias" => "total_revenue"
          }
        },
        "chart_type" => "line",
        "options" => %{
          "title" => "Rental Revenue by Release Year",
          "responsive" => true
        }
      }
    })

    insert_or_update_view(%{
      name: "Monty Rental Revenue",
      context: "/pagila_films",
      params: %{
        "view_mode" => "graph",
        "x_axis" => %{
          "0" => %{
            "field" => "rating",
            "index" => "0",
            "alias" => "rating"
          }
        },
        "y_axis" => %{
          "0" => %{
            "field" => "film_id",
            "function" => "count",
            "index" => "0",
            "alias" => "film_count"
          },
          "1" => %{
            "field" => "length",
            "function" => "avg",
            "index" => "1",
            "alias" => "avg_length"
          },
          "2" => %{
            "field" => "replacement_cost",
            "function" => "avg",
            "index" => "2",
            "alias" => "avg_replacement_cost"
          }
        },
        "chart_type" => "bar",
        "options" => %{
          "title" => "Film Portfolio by Rating",
          "responsive" => true
        }
      }
    })

    # Graph View: Film Length by Category (with series)
    insert_or_update_view(%{
      name: "Film Length by Category and Rating",
      context: "/pagila_films",
      params: %{
        "view_mode" => "graph",
        "x_axis" => %{
          "0" => %{"field" => "rating", "index" => "0", "alias" => "rating"}
        },
        "y_axis" => %{
          "0" => %{
            "field" => "length",
            "function" => "avg",
            "index" => "0",
            "alias" => "avg_length",
            "series_type" => "line",
            "axis" => "right"
          },
          "1" => %{
            "field" => "film_id",
            "function" => "count",
            "index" => "1",
            "alias" => "film_count",
            "series_type" => "bar",
            "axis" => "left"
          }
        },
        "chart_type" => "bar",
        "options" => %{
          "title" => "Film Count and Avg Length by Rating",
          "y_axis_label" => "Film Count",
          "y2_axis_label" => "Average Length (minutes)",
          "stacked" => false,
          "responsive" => true
        }
      }
    })

    # Aggregate View: Actor Performance Metrics
    insert_or_update_view(%{
      name: "Actor Performance Metrics",
      context: "/pagila",
      params: %{
        "view_mode" => "aggregate",
        "group_by" => %{
          "0" => %{"field" => "first_name", "index" => "0", "alias" => "first_name"},
          "1" => %{"field" => "last_name", "index" => "1", "alias" => "last_name"}
        },
        "aggregates" => %{
          "0" => %{
            "field" => "actor_id",
            "function" => "count",
            "index" => "0",
            "alias" => "film_count"
          },
          "1" => %{
            "field" => "last_update",
            "function" => "max",
            "index" => "1",
            "alias" => "latest_update"
          }
        },
        "order_by" => %{
          "0" => %{"field" => "film_count", "dir" => "desc", "index" => "0"}
        }
      }
    })

    # Detail View: Film Inventory with Filters
    insert_or_update_view(%{
      name: "Action Films Detail",
      context: "/pagila_films",
      params: %{
        "view_mode" => "detail",
        "selected" => %{
          "0" => %{"field" => "title", "index" => "0", "alias" => "title"},
          "1" => %{"field" => "release_year", "index" => "1", "alias" => "year"},
          "2" => %{"field" => "rating", "index" => "2", "alias" => "rating"},
          "3" => %{"field" => "rental_rate", "index" => "3", "alias" => "price"},
          "4" => %{"field" => "length", "index" => "4", "alias" => "duration"}
        },
        "order_by" => %{
          "0" => %{"field" => "title", "dir" => "asc", "index" => "0"}
        },
        "per_page" => "50",
        "prevent_denormalization" => false,
        "filters" => %{
          "0" => %{"filter" => "rating", "value" => "PG", "comp" => "="}
        }
      }
    })

    # Graph View: Pie Chart - Special Features Distribution
    insert_or_update_view(%{
      name: "Special Features Distribution",
      context: "/pagila_films",
      params: %{
        "view_mode" => "graph",
        "x_axis" => %{
          "0" => %{"field" => "special_features", "index" => "0", "alias" => "feature"}
        },
        "y_axis" => %{
          "0" => %{
            "field" => "film_id",
            "function" => "count",
            "index" => "0",
            "alias" => "count"
          }
        },
        "chart_type" => "pie",
        "options" => %{
          "title" => "Distribution of Special Features",
          "responsive" => true,
          "legend" => %{"position" => "right"}
        }
      }
    })

    # Aggregate View: Revenue Analysis by Rating
    insert_or_update_view(%{
      name: "Revenue by Rating",
      context: "/pagila_films",
      params: %{
        "view_mode" => "graph",
        "x_axis" => %{
          "0" => %{"field" => "rating", "index" => "0", "alias" => "rating"}
        },
        "y_axis" => %{
          "0" => %{
            "field" => "film_id",
            "function" => "sum",
            "index" => "0",
            "alias" => "films"
          },
          "1" => %{
            "field" => "rental_rate",
            "function" => "sum",
            "index" => "1",
            "alias" => "revenue"
          }
        },
        "chart_type" => "bar",
        "options" => %{
          "title" => "Revenue and Film Count by Rating",
          "responsive" => true
        }
      }
    })

    # Graph View: Horizontal Bar - Top Languages
    insert_or_update_view(%{
      name: "Films by Language",
      context: "/pagila_films",
      params: %{
        "view_mode" => "graph",
        "x_axis" => %{
          "0" => %{"field" => "language.name", "index" => "0", "alias" => "language"}
        },
        "y_axis" => %{
          "0" => %{
            "field" => "film_id",
            "function" => "count",
            "index" => "0",
            "alias" => "film_count"
          }
        },
        "chart_type" => "bar",
        "options" => %{
          "title" => "Number of Films by Language",
          "responsive" => true
        }
      }
    })

    # Detail View: Recent Films with Subselect Support
    insert_or_update_view(%{
      name: "Recent Films with Actors",
      context: "/pagila_films",
      params: %{
        "view_mode" => "detail",
        "selected" => %{
          "0" => %{"field" => "title", "index" => "0", "alias" => "title"},
          "1" => %{"field" => "release_year", "index" => "1", "alias" => "year"},
          "2" => %{"field" => "rating", "index" => "2", "alias" => "rating"},
          "3" => %{"field" => "language_id", "index" => "3", "alias" => "language_id"},
          "4" => %{"field" => "rental_rate", "index" => "4", "alias" => "rate"}
        },
        "order_by" => %{
          "0" => %{"field" => "release_year", "dir" => "desc", "index" => "0"},
          "1" => %{"field" => "title", "dir" => "asc", "index" => "1"}
        },
        "per_page" => "25",
        "prevent_denormalization" => true
      }
    })

    # Detail View: Rating and Cast Explorer (stable field set for saved-view URL loading)
    insert_or_update_view(%{
      name: "Rating and Cast Explorer",
      context: "/pagila_films",
      params: %{
        "view_mode" => "detail",
        "selected" => %{
          "0" => %{"field" => "title", "index" => "0", "alias" => "film_title"},
          "1" => %{"field" => "rating", "index" => "1", "alias" => "mpaa_rating"},
          "2" => %{"field" => "release_year", "index" => "2", "alias" => "year"},
          "3" => %{"field" => "language_id", "index" => "3", "alias" => "language_id"},
          "4" => %{"field" => "rental_duration", "index" => "4", "alias" => "rental_days"}
        },
        "order_by" => %{
          "0" => %{"field" => "rating", "dir" => "asc", "index" => "0"},
          "1" => %{"field" => "title", "dir" => "asc", "index" => "1"}
        },
        "per_page" => "60",
        "prevent_denormalization" => false
      }
    })

    # Graph View: Multi-series Line Chart
    insert_or_update_view(%{
      name: "Rental Metrics Comparison",
      context: "/pagila_films",
      params: %{
        "view_mode" => "graph",
        "x_axis" => %{
          "0" => %{"field" => "rental_duration", "index" => "0", "alias" => "rental_days"}
        },
        "y_axis" => %{
          "0" => %{
            "field" => "rental_rate",
            "function" => "avg",
            "index" => "0",
            "alias" => "avg_rate"
          },
          "1" => %{
            "field" => "replacement_cost",
            "function" => "avg",
            "index" => "1",
            "alias" => "avg_cost"
          }
        },
        "chart_type" => "line",
        "options" => %{
          "title" => "Rental Rate vs Replacement Cost by Duration",
          "responsive" => true,
          "scales" => %{
            "yAxes" => [%{"ticks" => %{"beginAtZero" => true}}]
          }
        }
      }
    })
  end

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
end
