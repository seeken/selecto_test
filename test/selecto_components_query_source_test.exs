defmodule SelectoComponentsQuerySourceTest do
  use SelectoTest.DataCase

  alias SelectoComponents.Router

  test "legacy router preserves qualified selections without retargeting" do
    selecto = %Selecto{
      adapter: SelectoDBPostgreSQL.Adapter,
      connection: nil,
      domain: domain(),
      config: %{},
      set: %{
        selected: [],
        filtered: [],
        post_retarget_filters: [],
        order_by: [],
        group_by: []
      }
    }

    view_config = %{
      view_mode: "detail",
      selected: %{
        "uuid-1" => %{"field" => "film.description", "index" => "0"},
        "uuid-2" => %{"field" => "film.title", "index" => "1"}
      },
      filters: %{}
    }

    state = %{
      selecto: selecto,
      view_config: view_config,
      active_tab: nil,
      execution_error: nil,
      query_results: nil
    }

    assert {:ok, updated_state} =
             Router.handle_event("view-apply", %{"view_config" => view_config}, state)

    refute Selecto.Retarget.has_retarget?(updated_state.selecto)

    assert MapSet.new(updated_state.selecto.set.selected) ==
             MapSet.new(["film.description", "film.title"])
  end

  defp domain do
    %{
      source: %{
        source_table: "actors",
        primary_key: :actor_id,
        columns: %{
          actor_id: %{name: "Actor ID", type: :integer},
          first_name: %{name: "First Name", type: :string}
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
  end
end
