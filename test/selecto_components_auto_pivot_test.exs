defmodule SelectoComponentsAutoPivotTest do
  use SelectoTest.DataCase
  alias SelectoComponents.Router

  describe "automatic pivot detection" do
    test "automatically pivots when selected columns are not in base table" do
      # Create a domain with actors as source and films as a joined table
      domain = %{
        source: %{
          source_table: "actors",
          primary_key: :actor_id,
          columns: %{
            actor_id: %{name: "Actor ID", type: :integer},
            first_name: %{name: "First Name", type: :string},
            last_name: %{name: "Last Name", type: :string}
          },
          associations: %{
            films: %{
              queryable: :films,
              join_keys: [actor_id: :actor_id],
              owner_key: :actor_id,
              related_key: :actor_id
            }
          }
        },
        schemas: %{
          films: %{
            source_table: "films",
            primary_key: :film_id,
            columns: %{
              film_id: %{name: "Film ID", type: :integer},
              title: %{name: "Title", type: :string},
              release_year: %{name: "Release Year", type: :integer},
              rating: %{name: "Rating", type: :string}
            }
          }
        }
      }

      selecto = %Selecto{
        postgrex_opts: nil,
        adapter: nil,
        connection: nil,
        domain: domain,
        config: %{},
        set: %{
          selected: [],
          filtered: [],
          post_pivot_filters: [],
          order_by: [],
          group_by: []
        }
      }

      # Create state with selecto and view config selecting film columns
      state = %{
        selecto: selecto,
        view_config: %{
          view_mode: "detail",
          selected: ["title", "release_year", "rating"],
          filters: %{}
        },
        active_tab: nil,
        execution_error: nil,
        query_results: nil
      }

      # Mock the State module's update_view_config
      params = %{
        "view_config" => %{
          "view_mode" => "detail",
          "selected" => ["title", "release_year", "rating"]
        }
      }

      # The router should detect that selected columns (title, release_year, rating)
      # are not in the source table (actors) and automatically pivot to films
      {:ok, updated_state} = Router.handle_event("view-apply", params, state)

      # Check that pivot was applied
      assert updated_state.selecto.set[:pivot_state] != nil
      assert updated_state.selecto.set[:pivot_state].target_schema == :films
    end

    test "does not pivot when all selected columns are in base table" do
      # Create a domain with actors as source
      domain = %{
        source: %{
          columns: %{
            actor_id: %{name: "Actor ID", type: :integer},
            first_name: %{name: "First Name", type: :string},
            last_name: %{name: "Last Name", type: :string}
          }
        },
        schemas: %{}
      }

      selecto = %Selecto{
        postgrex_opts: nil,
        adapter: nil,
        connection: nil,
        domain: domain,
        config: %{},
        set: %{
          selected: [],
          filtered: [],
          post_pivot_filters: [],
          order_by: [],
          group_by: []
        }
      }

      # Create state selecting only actor columns
      state = %{
        selecto: selecto,
        view_config: %{
          view_mode: "detail",
          selected: ["first_name", "last_name"],
          filters: %{}
        },
        active_tab: nil,
        execution_error: nil,
        query_results: nil
      }

      params = %{
        "view_config" => %{
          "view_mode" => "detail",
          "selected" => ["first_name", "last_name"]
        }
      }

      # The router should not pivot since all columns are in source
      {:ok, updated_state} = Router.handle_event("view-apply", params, state)

      # Check that no pivot was applied
      assert updated_state.selecto.set[:pivot_state] == nil
    end

    test "handles aggregate view with auto pivot" do
      # Create a domain with customers as source and rentals as joined
      domain = %{
        source: %{
          columns: %{
            customer_id: %{name: "Customer ID", type: :integer},
            first_name: %{name: "First Name", type: :string},
            last_name: %{name: "Last Name", type: :string}
          },
          associations: %{
            rentals: %{
              queryable: :rentals,
              join_keys: [customer_id: :customer_id]
            }
          }
        },
        schemas: %{
          rentals: %{
            columns: %{
              rental_id: %{name: "Rental ID", type: :integer},
              rental_date: %{name: "Rental Date", type: :date},
              return_date: %{name: "Return Date", type: :date},
              amount: %{name: "Amount", type: :decimal}
            }
          }
        }
      }

      selecto = %Selecto{
        postgrex_opts: nil,
        adapter: nil,
        connection: nil,
        domain: domain,
        config: %{},
        set: %{
          selected: [],
          filtered: [],
          post_pivot_filters: [],
          order_by: [],
          group_by: []
        }
      }

      # Create aggregate view selecting rental columns
      state = %{
        selecto: selecto,
        view_config: %{
          view_mode: "aggregate",
          group_by: %{
            "1" => %{"field" => "rental_date", "index" => "1"}
          },
          aggregate: %{
            "1" => %{"field" => "amount", "format" => "sum", "index" => "1"}
          },
          filters: %{}
        },
        active_tab: nil,
        execution_error: nil,
        query_results: nil
      }

      params = %{
        "view_config" => state.view_config
      }

      # Should pivot to rentals table for rental_date and amount columns
      {:ok, updated_state} = Router.handle_event("view-apply", params, state)

      assert updated_state.selecto.set[:pivot_state] != nil
      assert updated_state.selecto.set[:pivot_state].target_schema == :rentals
    end

    test "automatically pivots with qualified column names (e.g., film.description)" do
      # Create a domain with actors as source and films as a joined table
      domain = %{
        source: %{
          columns: %{
            actor_id: %{name: "Actor ID", type: :integer},
            first_name: %{name: "First Name", type: :string},
            last_name: %{name: "Last Name", type: :string}
          },
          associations: %{
            film: %{
              queryable: :film,
              join_keys: [actor_id: :actor_id]
            }
          }
        },
        schemas: %{
          film: %{
            columns: %{
              film_id: %{name: "Film ID", type: :integer},
              title: %{name: "Title", type: :string},
              description: %{name: "Description", type: :text},
              release_year: %{name: "Release Year", type: :integer},
              rating: %{name: "Rating", type: :string}
            }
          }
        }
      }

      selecto = %Selecto{
        postgrex_opts: nil,
        adapter: nil,
        connection: nil,
        domain: domain,
        config: %{},
        set: %{
          selected: [],
          filtered: [],
          post_pivot_filters: [],
          order_by: [],
          group_by: []
        }
      }

      # Create state with qualified column names in selected map (as would come from UI)
      state = %{
        selecto: selecto,
        view_config: %{
          view_mode: "detail",
          selected: %{
            "uuid-1" => %{"field" => "film.description", "index" => "0"},
            "uuid-2" => %{"field" => "film.title", "index" => "1"}
          },
          filters: %{}
        },
        active_tab: nil,
        execution_error: nil,
        query_results: nil
      }

      params = %{
        "view_config" => state.view_config
      }

      # The router should detect qualified column names and pivot to film table
      {:ok, updated_state} = Router.handle_event("view-apply", params, state)

      # Check that pivot was applied to film table
      assert updated_state.selecto.set[:pivot_state] != nil
      assert updated_state.selecto.set[:pivot_state].target_schema == :film
    end

    test "handles mixed qualified and simple column names" do
      # Create a domain with actors as source and films as joined
      domain = %{
        source: %{
          columns: %{
            actor_id: %{name: "Actor ID", type: :integer},
            first_name: %{name: "First Name", type: :string},
            last_name: %{name: "Last Name", type: :string}
          },
          associations: %{
            film: %{
              queryable: :film,
              join_keys: [actor_id: :actor_id]
            }
          }
        },
        schemas: %{
          film: %{
            columns: %{
              film_id: %{name: "Film ID", type: :integer},
              title: %{name: "Title", type: :string},
              description: %{name: "Description", type: :text}
            }
          }
        }
      }

      selecto = %Selecto{
        postgrex_opts: nil,
        adapter: nil,
        connection: nil,
        domain: domain,
        config: %{},
        set: %{
          selected: [],
          filtered: [],
          post_pivot_filters: [],
          order_by: [],
          group_by: []
        }
      }

      # Mix of qualified and simple column names
      state = %{
        selecto: selecto,
        view_config: %{
          view_mode: "detail",
          selected: %{
            "uuid-1" => %{"field" => "first_name", "index" => "0"},
            "uuid-2" => %{"field" => "film.title", "index" => "1"},
            "uuid-3" => %{"field" => "last_name", "index" => "2"}
          },
          filters: %{}
        },
        active_tab: nil,
        execution_error: nil,
        query_results: nil
      }

      params = %{
        "view_config" => state.view_config
      }

      # Should pivot because of the film.title qualified column
      {:ok, updated_state} = Router.handle_event("view-apply", params, state)

      assert updated_state.selecto.set[:pivot_state] != nil
      assert updated_state.selecto.set[:pivot_state].target_schema == :film
    end
  end
end
