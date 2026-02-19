defmodule SelectoTest.PagilaDomainFilms do
  use SelectoTestWeb, :verified_routes
  use SelectoTest.SavedViewContext
  use SelectoTest.SavedViewConfigContext

  alias Selecto.Config.Overlay

  # Fixed: rating filter configured in filters section for dropdown UI

  def films_domain() do
    domain()
  end

  def domain() do
    base_films_domain()
    |> Overlay.merge(overlay())
  end

  defp overlay do
    if Code.ensure_loaded?(SelectoTest.Overlays.PagilaDomainFilmsOverlay) do
      SelectoTest.Overlays.PagilaDomainFilmsOverlay.overlay()
    else
      %{}
    end
  end

  defp base_films_domain() do
    ### customer info, payments and rentals
    %{
      source: %{
        source_table: "film",
        primary_key: :film_id,
        schema_module: SelectoTest.Store.Film,
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
          :special_features
        ],
        redact_fields: [],
        columns: %{
          film_id: %{type: :integer},
          title: %{type: :string},
          description: %{type: :string},
          release_year: %{type: :integer},
          language_id: %{type: :integer},
          rental_duration: %{type: :integer},
          rental_rate: %{type: :decimal},
          length: %{type: :integer},
          replacement_cost: %{type: :decimal},
          rating: %{type: :string},
          special_features: %{type: {:array, :string}}
        },
        associations: %{
          language: %{
            queryable: :language,
            field: :language,
            owner_key: :language_id,
            related_key: :language_id
          },
          film_actors: %{
            queryable: :film_actors,
            field: :film_actors,
            owner_key: :film_id,
            related_key: :film_id
          }
        }
      },
      schemas: %{
        language: %{
          source_table: "language",
          primary_key: :language_id,
          schema_module: SelectoTest.Store.Language,
          fields: [:language_id, :name],
          redact_fields: [],
          columns: %{
            language_id: %{type: :integer},
            name: %{type: :string}
          },
          associations: %{}
        },
        film_actors: %{
          source_table: "film_actor",
          primary_key: :actor_id,
          schema_module: SelectoTest.Store.FilmActor,
          fields: [:film_id, :actor_id],
          redact_fields: [],
          columns: %{
            film_id: %{type: :integer},
            actor_id: %{type: :integer}
          },
          associations: %{
            actor: %{
              queryable: :actor,
              field: :actor,
              owner_key: :actor_id,
              related_key: :actor_id
            }
          }
        },
        actor: %{
          source_table: "actor",
          primary_key: :actor_id,
          schema_module: SelectoTest.Store.Actor,
          fields: [:actor_id, :first_name, :last_name],
          redact_fields: [],
          columns: %{
            actor_id: %{type: :integer},
            first_name: %{type: :string},
            last_name: %{type: :string}
          },
          associations: %{
            film_actors: %{
              queryable: :film_actors,
              field: :film_actors,
              owner_key: :actor_id,
              related_key: :actor_id
            }
          }
        }
      },
      name: "Film",
      default_selected: ["title"],
      default_order_by: ["title"],
      default_group_by: ["release_year"],
      default_aggregate: [{"film_id", %{"format" => "count"}}],
      filters: %{
        "film_rating" => %{
          name: "Film: Rating",
          type: :select_options,
          option_provider: %{
            type: :enum,
            schema: SelectoTest.Store.Film,
            field: :rating
          },
          multiple: true,
          searchable: false,
          apply: fn _selecto, filter ->
            {"rating", filter["value"]}
          end
        }
      },
      custom_columns: %{
        "film_link" => %{
          name: "Film Link",
          requires_select: ["film_id", "title"],
          format: :link,
          link_parts: fn {id, title} -> {~p[/pagila/film/#{id}], title} end
        },
        "fulltext" => %{
          field: "fulltext",
          type: :tsvector,
          name: "Title and Description Search",
          make_filter: true
        }
      },
      joins: %{
        # categories: %{
        #   name: "Categories",
        #   type: :tag
        # },
        language: %{
          name: "Film Language",
          # Dimension type: local table has ID to dimension table that provides enriched data
          type: :dimension,
          # the interesting data. So in this case, film has language[name], we will never care about language_id
          # We do not want to give 2 language ID columns to pick from, so will skip the remote, and skip date/update
          # info from the remote table. Lookup_value is the only col we will add from remote table (can be List to add more than one)
          dimension: :name
        },
        film_actors: %{
          name: "Film Actors",
          type: :left,
          joins: %{
            actor: %{
              name: "Actor",
              type: :left
            }
          }
        }
      }
    }
  end

  @doc """
  Returns the base films domain configuration without overlay merging.
  Useful for testing and debugging the raw configuration.
  """
  def base_domain do
    base_films_domain()
  end

  @doc """
  Debug configuration for the Pagila Films domain.
  Shows detailed query information for development.
  """
  def debug_config do
    %{
      enabled: true,
      show_query: true,
      show_params: true,
      show_timing: true,
      show_row_count: true,
      show_execution_plan: false,
      format_sql: true,
      max_param_length: 200,
      views: %{
        aggregate: %{
          show_query: true,
          show_timing: true,
          show_row_count: true
        },
        detail: %{
          show_query: true,
          show_params: true,
          show_row_count: true
        },
        graph: %{
          show_query: true,
          show_timing: true,
          show_row_count: false
        }
      }
    }
  end
end
