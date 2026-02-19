defmodule DocsSubselectsExamplesTest do
  use ExUnit.Case, async: true

  @moduledoc """
  These tests demonstrate the subselect functionality in Selecto.
  They have been updated to use the actual Selecto API.

  Subselects allow fetching related data as aggregated arrays (JSON, PostgreSQL arrays, etc.)
  without denormalizing the result set.
  """

  # Helper to configure test Selecto instance with proper domain structure
  defp configure_test_selecto(table) do
    domain_config =
      case table do
        "attendees" ->
          %{
            name: "Attendees",
            source: %{
              source_table: "attendees",
              primary_key: :attendee_id,
              fields: [:attendee_id, :name, :email, :event_id],
              redact_fields: [],
              columns: %{
                attendee_id: %{type: :integer},
                name: %{type: :string},
                email: %{type: :string},
                event_id: %{type: :integer}
              },
              associations: %{
                orders: %{
                  queryable: :orders,
                  field: :orders,
                  owner_key: :attendee_id,
                  related_key: :attendee_id
                }
              }
            },
            schemas: %{
              orders: %{
                source_table: "orders",
                primary_key: :order_id,
                fields: [
                  :order_id,
                  :attendee_id,
                  :product_name,
                  :quantity,
                  :price,
                  :status,
                  :total,
                  :created_at
                ],
                redact_fields: [],
                columns: %{
                  order_id: %{type: :integer},
                  attendee_id: %{type: :integer},
                  product_name: %{type: :string},
                  quantity: %{type: :integer},
                  price: %{type: :decimal},
                  status: %{type: :string},
                  total: %{type: :decimal},
                  created_at: %{type: :utc_datetime}
                },
                associations: %{}
              }
            },
            joins: %{}
          }

        "events" ->
          %{
            name: "Events",
            source: %{
              source_table: "events",
              primary_key: :event_id,
              fields: [:event_id, :name, :date],
              redact_fields: [],
              columns: %{
                event_id: %{type: :integer},
                name: %{type: :string},
                date: %{type: :date}
              },
              associations: %{
                attendees: %{
                  queryable: :attendees,
                  field: :attendees,
                  owner_key: :event_id,
                  related_key: :event_id
                },
                sponsors: %{
                  queryable: :sponsors,
                  field: :sponsors,
                  owner_key: :event_id,
                  related_key: :event_id
                }
              }
            },
            schemas: %{
              attendees: %{
                source_table: "attendees",
                primary_key: :attendee_id,
                fields: [:attendee_id, :name, :email, :event_id],
                redact_fields: [],
                columns: %{
                  attendee_id: %{type: :integer},
                  name: %{type: :string},
                  email: %{type: :string},
                  event_id: %{type: :integer}
                },
                associations: %{}
              },
              sponsors: %{
                source_table: "sponsors",
                primary_key: :sponsor_id,
                fields: [:sponsor_id, :event_id, :company, :amount],
                redact_fields: [],
                columns: %{
                  sponsor_id: %{type: :integer},
                  event_id: %{type: :integer},
                  company: %{type: :string},
                  amount: %{type: :decimal}
                },
                associations: %{}
              }
            },
            joins: %{}
          }

        "posts" ->
          %{
            name: "Posts",
            source: %{
              source_table: "posts",
              primary_key: :post_id,
              fields: [:post_id, :title, :content, :author_id],
              redact_fields: [],
              columns: %{
                post_id: %{type: :integer},
                title: %{type: :string},
                content: %{type: :string},
                author_id: %{type: :integer}
              },
              associations: %{
                comments: %{
                  queryable: :comments,
                  field: :comments,
                  owner_key: :post_id,
                  related_key: :post_id
                },
                tags: %{
                  queryable: :tags,
                  field: :tags,
                  owner_key: :post_id,
                  related_key: :post_id
                }
              }
            },
            schemas: %{
              comments: %{
                source_table: "comments",
                primary_key: :comment_id,
                fields: [:comment_id, :post_id, :comment_text, :created_at],
                redact_fields: [],
                columns: %{
                  comment_id: %{type: :integer},
                  post_id: %{type: :integer},
                  comment_text: %{type: :string},
                  created_at: %{type: :utc_datetime}
                },
                associations: %{}
              },
              tags: %{
                source_table: "tags",
                primary_key: :tag_id,
                fields: [:tag_id, :post_id, :tag_name],
                redact_fields: [],
                columns: %{
                  tag_id: %{type: :integer},
                  post_id: %{type: :integer},
                  tag_name: %{type: :string}
                },
                associations: %{}
              }
            },
            joins: %{}
          }

        _ ->
          %{
            name: "Default",
            source: %{
              source_table: table,
              primary_key: :id,
              fields: [:id],
              redact_fields: [],
              columns: %{
                id: %{type: :integer}
              },
              associations: %{}
            },
            schemas: %{},
            joins: %{}
          }
      end

    Selecto.configure(domain_config, :test_connection)
  end

  describe "Basic Subselect Usage" do
    test "simple subselect with JSON aggregation" do
      selecto = configure_test_selecto("attendees")

      result =
        selecto
        |> Selecto.select(["name", "email"])
        |> Selecto.subselect([
          %{
            target_schema: :orders,
            fields: [:product_name, :quantity],
            format: :json_agg,
            alias: "orders",
            filters: [],
            order_by: []
          }
        ])

      # Verify subselect was added
      assert result.set[:subselected] != nil
      assert length(result.set[:subselected]) == 1

      [subselect | _] = result.set[:subselected]
      assert subselect.target_schema == :orders
      assert subselect.fields == [:product_name, :quantity]
      assert subselect.format == :json_agg
    end

    test "multiple fields in subselect" do
      selecto = configure_test_selecto("attendees")

      result =
        selecto
        |> Selecto.subselect([
          %{
            target_schema: :orders,
            fields: [:product_name, :quantity, :price],
            format: :json_agg,
            alias: "order_details",
            filters: [],
            order_by: []
          }
        ])

      assert result.set[:subselected] != nil
      [subselect | _] = result.set[:subselected]
      assert length(subselect.fields) == 3
      assert :price in subselect.fields
    end

    test "multiple subselects for different relationships" do
      selecto = configure_test_selecto("events")

      result =
        selecto
        |> Selecto.select(["name", "date"])
        |> Selecto.subselect([
          %{
            target_schema: :attendees,
            fields: [:name, :email],
            format: :json_agg,
            alias: "attendees",
            filters: [],
            order_by: []
          },
          %{
            target_schema: :sponsors,
            fields: [:company, :amount],
            format: :json_agg,
            alias: "sponsors",
            filters: [],
            order_by: []
          }
        ])

      assert result.set[:subselected] != nil
      assert length(result.set[:subselected]) == 2

      [attendees_subselect, sponsors_subselect] = result.set[:subselected]
      assert attendees_subselect.target_schema == :attendees
      assert sponsors_subselect.target_schema == :sponsors
    end
  end

  describe "Advanced Subselect Configuration" do
    test "subselect with ordering" do
      selecto = configure_test_selecto("attendees")

      result =
        selecto
        |> Selecto.subselect([
          %{
            target_schema: :orders,
            fields: [:product_name, :quantity, :price],
            format: :json_agg,
            alias: "order_items",
            filters: [],
            order_by: [{:desc, :created_at}]
          }
        ])

      assert result.set[:subselected] != nil
      [subselect | _] = result.set[:subselected]
      assert subselect.order_by == [{:desc, :created_at}]
    end

    test "subselect with filter conditions" do
      selecto = configure_test_selecto("attendees")

      result =
        selecto
        |> Selecto.subselect([
          %{
            target_schema: :orders,
            fields: [:product_name, :quantity],
            format: :json_agg,
            alias: "completed_orders",
            filters: [{"status", "completed"}, {"total", {:>, 100}}],
            order_by: []
          }
        ])

      assert result.set[:subselected] != nil
      [subselect | _] = result.set[:subselected]
      assert length(subselect.filters) == 2
      assert {"status", "completed"} in subselect.filters
      assert {"total", {:>, 100}} in subselect.filters
    end
  end

  describe "Different Aggregation Formats" do
    test "JSON aggregation (default)" do
      selecto = configure_test_selecto("attendees")

      result =
        selecto
        |> Selecto.subselect([
          %{
            target_schema: :orders,
            fields: [:product_name, :quantity],
            format: :json_agg,
            alias: "orders_json",
            filters: [],
            order_by: []
          }
        ])

      assert result.set[:subselected] != nil
      [subselect | _] = result.set[:subselected]
      assert subselect.format == :json_agg
    end

    test "PostgreSQL array aggregation" do
      selecto = configure_test_selecto("attendees")

      result =
        selecto
        |> Selecto.subselect([
          %{
            target_schema: :orders,
            fields: [:product_name],
            format: :array_agg,
            alias: "product_names",
            filters: [],
            order_by: []
          }
        ])

      assert result.set[:subselected] != nil
      [subselect | _] = result.set[:subselected]
      assert subselect.format == :array_agg
      assert length(subselect.fields) == 1
    end

    test "string aggregation with separator" do
      selecto = configure_test_selecto("posts")

      result =
        selecto
        |> Selecto.subselect([
          %{
            target_schema: :tags,
            fields: [:tag_name],
            format: :string_agg,
            alias: "tag_list",
            separator: ", ",
            filters: [],
            order_by: []
          }
        ])

      assert result.set[:subselected] != nil
      [subselect | _] = result.set[:subselected]
      assert subselect.format == :string_agg
      assert subselect.separator == ", "
    end

    test "count aggregation" do
      selecto = configure_test_selecto("posts")

      result =
        selecto
        |> Selecto.subselect([
          %{
            target_schema: :comments,
            fields: [:comment_id],
            format: :count,
            alias: "comment_count",
            filters: [],
            order_by: []
          }
        ])

      assert result.set[:subselected] != nil
      [subselect | _] = result.set[:subselected]
      assert subselect.format == :count
      assert subselect.alias == "comment_count"
    end
  end

  describe "Complex Subselect Examples" do
    test "e-commerce order with nested items" do
      selecto = configure_test_selecto("attendees")

      result =
        selecto
        |> Selecto.select(["attendee_id", "name", "email"])
        |> Selecto.subselect([
          %{
            target_schema: :orders,
            fields: [:order_id, :product_name, :quantity, :price],
            format: :json_agg,
            alias: "items",
            filters: [{"status", "completed"}],
            order_by: [{:asc, :created_at}]
          }
        ])
        |> Selecto.filter([{"event_id", 123}])

      # Verify the structure
      assert result.set[:subselected] != nil
      assert result.set[:selected] == ["attendee_id", "name", "email"]
      assert result.set[:filtered] == [{"event_id", 123}]

      [subselect | _] = result.set[:subselected]
      assert subselect.alias == "items"
      assert {"status", "completed"} in subselect.filters
    end

    test "user profile with multiple related data" do
      selecto = configure_test_selecto("events")

      result =
        selecto
        |> Selecto.select(["event_id", "name", "date"])
        |> Selecto.subselect([
          %{
            target_schema: :attendees,
            fields: [:name, :email],
            format: :json_agg,
            alias: "attendee_list",
            filters: [],
            order_by: [{:asc, :name}]
          },
          %{
            target_schema: :sponsors,
            fields: [:company, :amount],
            format: :json_agg,
            alias: "sponsor_list",
            filters: [{"amount", {:>=, 1000}}],
            order_by: [{:desc, :amount}]
          }
        ])

      assert result.set[:subselected] != nil
      assert length(result.set[:subselected]) == 2

      [attendees, sponsors] = result.set[:subselected]
      assert attendees.alias == "attendee_list"
      assert sponsors.alias == "sponsor_list"
      assert {"amount", {:>=, 1000}} in sponsors.filters
    end
  end

  describe "Subselect Format Validation" do
    test "all aggregation formats are accepted" do
      selecto = configure_test_selecto("attendees")

      formats = [:json_agg, :array_agg, :string_agg, :count]

      Enum.each(formats, fn format ->
        result =
          selecto
          |> Selecto.subselect([
            %{
              target_schema: :orders,
              fields: [:order_id],
              format: format,
              alias: "#{format}_test",
              filters: [],
              order_by: []
            }
          ])

        assert result.set[:subselected] != nil
        [subselect | _] = result.set[:subselected]
        assert subselect.format == format
      end)
    end

    test "subselect preserves selecto structure" do
      selecto = configure_test_selecto("attendees")

      original_keys = Map.keys(selecto)

      result =
        selecto
        |> Selecto.subselect([
          %{
            target_schema: :orders,
            fields: [:order_id],
            format: :count,
            alias: "order_count",
            filters: [],
            order_by: []
          }
        ])

      # All original keys should still be present
      assert Map.keys(result) == original_keys

      # Subselected field should be added to set
      assert Map.has_key?(result.set, :subselected)
    end
  end
end
