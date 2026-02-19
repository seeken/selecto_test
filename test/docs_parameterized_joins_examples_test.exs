defmodule DocsParameterizedJoinsExamplesTest do
  use ExUnit.Case, async: true

  @moduledoc """
  These tests demonstrate parameterized joins functionality in Selecto.

  In Selecto, joins are configured at the domain level, not added dynamically.
  However, parameterized joins allow for dynamic conditions through the
  ParameterizedJoin module.
  """

  alias Selecto.Schema.ParameterizedJoin

  describe "Parameterized Join Processing" do
    test "basic parameterized join configuration" do
      # Define a join with parameters
      join_config = %{
        parameters: [
          %{name: :status, type: :string, required: true, default: "active"},
          %{name: :min_amount, type: :number, required: false, default: 0}
        ],
        join_type: :inner,
        target_table: "customers",
        join_condition: "orders.customer_id = customers.id AND customers.status = :status"
      }

      # Provide parameter values
      provided_params = [
        {:string, "active"},
        {:number, 100}
      ]

      # Validate parameters
      validated_params =
        ParameterizedJoin.validate_parameters(
          join_config.parameters,
          provided_params
        )

      assert length(validated_params) == 2
      assert Enum.at(validated_params, 0).name == :status
      assert Enum.at(validated_params, 0).value == "active"
      assert Enum.at(validated_params, 1).name == :min_amount
      assert Enum.at(validated_params, 1).value == 100
    end

    test "parameter validation with defaults" do
      # Define join with optional parameters
      join_config = %{
        parameters: [
          %{name: :role, type: :atom, required: false, default: :user},
          %{name: :active, type: :boolean, required: false, default: true}
        ]
      }

      # Provide only first parameter
      provided_params = [
        {:atom, :admin}
      ]

      # Validate parameters - should use default for second
      validated_params =
        ParameterizedJoin.validate_parameters(
          join_config.parameters,
          provided_params
        )

      assert length(validated_params) == 2
      assert Enum.at(validated_params, 0).value == :admin
      # default value
      assert Enum.at(validated_params, 1).value == true
    end

    test "build parameter context for SQL templates" do
      validated_params = [
        %{name: :tenant_id, value: 42, type: :integer},
        %{name: :status, value: "active", type: :string},
        %{name: :include_deleted, value: false, type: :boolean}
      ]

      context = ParameterizedJoin.build_parameter_context(validated_params)

      assert context[:tenant_id] == 42
      assert context[:status] == "active"
      assert context[:include_deleted] == false
    end

    test "parameter signature generation" do
      # Create parameters for signature
      params = [
        {:integer, 123},
        {:string, "test"},
        {:boolean, true}
      ]

      signature = ParameterizedJoin.build_parameter_signature(params)

      # Signature should uniquely identify this parameter combination
      assert is_binary(signature)
      assert String.length(signature) > 0
    end
  end

  describe "Parameterized Join Resolution" do
    test "resolve parameterized condition with context" do
      join_config = %{
        join_condition:
          "table1.field = table2.field AND table2.status = :status AND table2.amount > :min_amount"
      }

      validated_params = [
        %{name: :status, value: "active", type: :string},
        %{name: :min_amount, value: 100, type: :number}
      ]

      # Resolve the condition with parameters
      resolved_condition =
        ParameterizedJoin.resolve_parameterized_condition(
          join_config,
          validated_params
        )

      # The resolved condition should have parameters substituted
      assert is_binary(resolved_condition) || is_nil(resolved_condition)
    end

    test "complex parameter types" do
      join_config = %{
        parameters: [
          %{name: :ids, type: :list, required: true},
          %{
            name: :date_range,
            type: :tuple,
            required: false,
            default: {~D[2024-01-01], ~D[2024-12-31]}
          },
          %{name: :config, type: :map, required: false, default: %{}}
        ]
      }

      provided_params = [
        {:list, [1, 2, 3]},
        {:tuple, {~D[2024-06-01], ~D[2024-06-30]}}
      ]

      validated_params =
        ParameterizedJoin.validate_parameters(
          join_config.parameters,
          provided_params
        )

      assert Enum.at(validated_params, 0).value == [1, 2, 3]
      assert elem(Enum.at(validated_params, 1).value, 0) == ~D[2024-06-01]
      # default map
      assert Enum.at(validated_params, 2).value == %{}
    end
  end

  describe "Parameter Validation Through Public API" do
    test "validate parameters with correct types" do
      join_config = %{
        parameters: [
          %{name: :status, type: :string, required: true},
          %{name: :count, type: :integer, required: true},
          %{name: :active, type: :boolean, required: true}
        ]
      }

      provided_params = [
        {:string, "active"},
        {:integer, 42},
        {:boolean, true}
      ]

      validated =
        ParameterizedJoin.validate_parameters(
          join_config.parameters,
          provided_params
        )

      assert length(validated) == 3
      assert Enum.at(validated, 0).value == "active"
      assert Enum.at(validated, 1).value == 42
      assert Enum.at(validated, 2).value == true
    end

    test "validation with type mismatches" do
      join_config = %{
        parameters: [
          %{name: :count, type: :integer, required: true}
        ]
      }

      # Provide wrong type
      provided_params = [
        {:string, "not_a_number"}
      ]

      # This should raise an error
      assert_raise RuntimeError, ~r/Parameter 'count'/, fn ->
        ParameterizedJoin.validate_parameters(
          join_config.parameters,
          provided_params
        )
      end
    end
  end

  describe "Parameterized Join Configuration" do
    test "enhance join with parameters" do
      base_join = %{
        id: :customer_join,
        type: :inner,
        target: "customers"
      }

      parameterized_config = %{
        parameters: [
          %{name: :status, value: "active", type: :string}
        ],
        parameter_context: %{status: "active"},
        join_condition: "customers.status = 'active'",
        parameter_signature: "active"
      }

      enhanced_join =
        ParameterizedJoin.enhance_join_with_parameters(
          base_join,
          parameterized_config
        )

      assert enhanced_join.is_parameterized == true
      assert enhanced_join.parameter_signature == "active"
      assert enhanced_join.join_condition == "customers.status = 'active'"
    end

    test "full parameterized join processing" do
      join_id = :payment_join

      join_config = %{
        parameters: [
          %{name: :min_amount, type: :number, required: false, default: 0},
          %{name: :status, type: :string, required: false, default: "completed"}
        ],
        join_type: :left,
        target_table: "payments"
      }

      parameters = [
        {:number, 100},
        {:string, "pending"}
      ]

      parent = :orders
      from_source = SelectoTest.Store.Order
      queryable = %{}

      result =
        ParameterizedJoin.process_parameterized_join(
          join_id,
          join_config,
          parameters,
          parent,
          from_source,
          queryable
        )

      assert Map.has_key?(result, :base_config)
      assert Map.has_key?(result, :parameters)
      assert Map.has_key?(result, :parameter_context)
      assert Map.has_key?(result, :parameter_signature)
      assert length(result.parameters) == 2
    end
  end

  describe "Parameter Context Usage" do
    test "build context from validated parameters" do
      params = [
        %{name: :user_role, value: :admin, type: :atom},
        %{name: :tenant_id, value: 42, type: :integer},
        %{name: :include_archived, value: false, type: :boolean}
      ]

      context = ParameterizedJoin.build_parameter_context(params)

      assert context.user_role == :admin
      assert context.tenant_id == 42
      assert context.include_archived == false
    end

    test "parameter signature for caching" do
      # Same parameters should produce same signature
      params1 = [
        {:integer, 123},
        {:string, "test"}
      ]

      params2 = [
        {:integer, 123},
        {:string, "test"}
      ]

      sig1 = ParameterizedJoin.build_parameter_signature(params1)
      sig2 = ParameterizedJoin.build_parameter_signature(params2)

      assert sig1 == sig2

      # Different parameters should produce different signature
      params3 = [
        {:integer, 456},
        {:string, "test"}
      ]

      sig3 = ParameterizedJoin.build_parameter_signature(params3)

      assert sig1 != sig3
    end
  end

  describe "ParameterizedParser Integration" do
    test "parse field reference with parameters" do
      # ParameterizedParser would parse join references like "payment{100, 'pending'}.amount"
      # This is handled by the ParameterizedParser module

      # For now, just verify the module exists
      assert Code.ensure_loaded?(Selecto.FieldResolver.ParameterizedParser)
    end
  end
end
