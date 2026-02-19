defmodule SelectoTest.PagilaDomain do
  import Phoenix.Component
  use SelectoTestWeb, :verified_routes
  import SelectoComponents.Components.Common

  use SelectoTest.SavedViewContext
  use SelectoTest.SavedViewConfigContext
  # Film rating aggregation filters have been tested and are working correctly as per test results

  alias Selecto.Config.Overlay

  def actors_domain() do
    base_actors_domain()
    |> Overlay.merge(overlay())
  end

  defp overlay do
    if Code.ensure_loaded?(SelectoTest.Overlays.PagilaDomainOverlay) do
      SelectoTest.Overlays.PagilaDomainOverlay.overlay()
    else
      %{}
    end
  end

  defp base_actors_domain() do
    %{
      source: %{
        source_table: "actor",
        primary_key: :actor_id,
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
      },
      schemas: %{
        film_actors: %{
          source_table: "film_actor",
          primary_key: :film_id,
          fields: [:film_id, :actor_id],
          redact_fields: [],
          columns: %{
            film_id: %{type: :integer},
            actor_id: %{type: :integer}
          },
          associations: %{
            film: %{
              queryable: :film,
              field: :film,
              owner_key: :film_id,
              related_key: :film_id
            }
          }
        },
        film: %{
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
            }
          }
        },
        language: %{
          source_table: "language",
          primary_key: :language_id,
          fields: [:language_id, :name],
          redact_fields: [],
          columns: %{
            language_id: %{type: :integer},
            name: %{type: :string}
          },
          associations: %{}
        }
      },
      name: "Actor",

      ### Will always be applied
      # required_filters: [{"actor_id", {">=", 1}}],

      ## Starting form params
      default_selected: ["first_name", "last_name"],
      default_order_by: ["last_name"],
      default_group_by: ["full_name"],
      default_aggregate: [{"actor_id", %{"format" => "count"}}],

      # Custom filters that cannot be created automatically from the schema
      filters: %{
        "actor_has_ratings" => %{
          name: "Actor Has Ratings",
          component: &actor_ratings/1,
          type: :component,
          apply: &actor_ratings_apply/2
        },
        "film_rating_select" => %{
          name: "Film Rating (Multiple)",
          type: :select_options,
          option_provider: %{
            type: :enum,
            schema: SelectoTest.Store.Film,
            field: :rating
          },
          multiple: true,
          searchable: false,
          apply: fn _selecto, filter ->
            {"film[rating]", filter["value"]}
          end
        }
      },

      # Custom columns that cannot be created from the schema
      custom_columns: %{
        ### Example custom column with group-by and filter directives
        # Test error column - will cause SQL error
        "error_test" => %{
          name: "Error Test Column",
          select: {:raw, "1/0 as division_by_zero_error"}
        },
        "full_name" => %{
          name: "Full Name",
          ### concat_ws?
          select: {:concat, ["first_name", {:literal_string, " "}, "last_name"]},
          ### we will always get a tuple of select + group_by_filter_select here
          group_by_format: fn {a, _id}, _def -> a end,
          group_by_filter: "actor_id",
          group_by_filter_select: ["full_name", "actor_id"]
        },

        #### Example Custom Column Component with subquery and config component
        "actor_card" => %{
          name: "Actor Card",
          ## Can also be a plain list or function which takes the column configuration struct and returns list
          requires_select: fn conf ->
            limit =
              case Map.get(conf, "limit") do
                nil -> 5
                "" -> 5
                x when is_binary(x) -> String.to_integer(x)
              end

            # Note: Multiple selections of same column with different parameters need proper handling
            ~w(actor_id first_name last_name) ++
              [
                {:subquery,
                 [
                   "array(select row( f.title, f.release_year )",
                   " from film f join film_actor af on f.film_id = af.film_id",
                   " where af.actor_id = selecto_root.actor_id",
                   " order by release_year desc",
                   " limit ",
                   {:param, limit},
                   ")"
                 ], []}
              ]
          end,
          format: :component,
          component: &actor_card/1,
          configure_component: &actor_card_config/1,

          # Process function handles film card batch/individual operations
          process: &process_film_card/2
        }
      },
      joins: %{
        film_actors: %{
          name: "Actor-Film Join",
          type: :left,
          joins: %{
            film: %{
              name: "Film",
              type: :left,
              joins: %{
                language: %{
                  name: "Film Language",
                  # Dimension type: local table has ID to dimension table that provides enriched data
                  type: :dimension,
                  # the interesting data. So in this case, film has language[name], we will never care about language_id
                  # We do not want to give 2 language ID columns to pick from, so will skip the remote, and skip date/update
                  # info from the remote table. Lookup_value is the only col we will add from remote table (can be List to add more than one)
                  dimension: :name
                }
              },
              custom_columns: %{
                "film_link" => %{
                  name: "Film Link",
                  requires_select: ["film[film_id]", "film[title]"],
                  format: :link,
                  link_parts: fn {id, title} -> {~p[/pagila/film/#{id}], title} end
                }
              }
            }
          }
        }
      }
    }
  end

  @doc """
  Returns the base actors domain configuration without overlay merging.
  Useful for testing and debugging the raw configuration.
  """
  def base_domain do
    base_actors_domain()
  end

  def actor_ratings_apply(_selecto, f) do
    ratings = f["ratings"]

    {"actor_id",
     {
       :subquery,
       :in,
       [
         "(select actor_id from film_actor fa join film f on fa.film_id = f.film_id where f.rating = ANY(",
         {:param, ratings},
         "))"
       ]
     }}
  end

  def actor_ratings(assigns) do
    ~H"""
    <div>
      Actor Ratings!
      <label :for={v <- ~w(G PG PG-13 R NC-17)}>
        <input
          type="checkbox"
          name={"filters[#{@uuid}][ratings][]"}
          value={v}
          checked={Enum.member?(Map.get(@valmap, "ratings", []), v)}
        />
        {v}
      </label>
    </div>
    """
  end

  defp actor_card_config(assigns) do
    ~H"""
    <div>
      Show # of Most Recent Films:
      <.sc_input type="number" name={"#{@prefix}[limit]"} value={Map.get(@config, "limit", 5)} />
    </div>
    """
  end

  defp actor_card(assigns) do
    ~H"""
    <div>
      <%= with {actor_id, first_name, last_name, actor_films} <- @row do %>
        Actor Card for {actor_id} ({@config["limit"]}) {first_name}
        {last_name}

        <ul>
          <li :for={{title, year} <- actor_films}>
            {year}
            {title}
          </li>
        </ul>
      <% end %>
    </div>
    """
  end

  def process_film_card(selecto, params) do
    # Process film card data - can be handled individually or in batch depending on use case
    # This function allows for custom processing of film card results
    # Currently returns data as-is, but could be extended for:
    # - Batch processing for performance optimization
    # - Individual processing for real-time updates
    # - Custom formatting or enrichment
    {:ok, selecto, params}
  end

  @doc """
  Debug configuration for the Pagila domain.
  Controls what debug information is displayed in development mode.
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
          show_params: true,
          show_timing: true,
          show_row_count: true
        },
        detail: %{
          show_query: true,
          show_params: true,
          show_timing: true,
          show_row_count: true
        },
        graph: %{
          show_query: true,
          show_params: true,
          show_timing: true,
          show_row_count: true
        }
      }
    }
  end
end
