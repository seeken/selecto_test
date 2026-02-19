defmodule SelectoTest.SelectOptionsIntegrationTest do
  use ExUnit.Case, async: true

  alias Selecto.OptionProvider
  alias Mix.Selecto.SchemaAnalyzer

  describe "Film rating enum integration" do
    test "can detect film rating as enum select option" do
      # Test that our existing Film schema is detected correctly
      analysis = SchemaAnalyzer.analyze_schema(SelectoTest.Store.Film)

      # Should detect rating as an enum field
      rating_candidate =
        Enum.find(analysis.select_candidates, fn candidate ->
          candidate.field == :rating && candidate.option_provider.type == :enum
        end)

      assert rating_candidate != nil
      assert rating_candidate.option_provider.schema == SelectoTest.Store.Film
      assert rating_candidate.option_provider.field == :rating
    end

    test "can load film rating options" do
      provider = %{
        type: :enum,
        schema: SelectoTest.Store.Film,
        field: :rating
      }

      assert {:ok, options} = OptionProvider.load_options(provider)

      # Should include MPAA ratings
      values = Enum.map(options, fn {value, _display} -> value end)
      assert "G" in values
      assert "PG" in values
      assert "PG-13" in values
      assert "R" in values
      assert "NC-17" in values
    end

    test "generates proper domain config for Film schema" do
      config = SchemaAnalyzer.generate_full_domain_config(SelectoTest.Store.Film)

      # Should have custom columns section
      custom_columns = Map.get(config, :custom_columns, %{})

      # Should have rating as select option
      rating_config = Map.get(custom_columns, "rating")
      assert rating_config != nil
      assert rating_config.option_provider.type == :enum
      # Enums default to multiple selection
      assert rating_config.multiple == true
      # Enums default to non-searchable
      assert rating_config.searchable == false
    end
  end

  describe "Association detection integration" do
    test "detects language association in Film schema" do
      analysis =
        SchemaAnalyzer.analyze_schema(SelectoTest.Store.Film,
          include_associations: true
        )

      # Should detect language as association
      language_candidate =
        Enum.find(analysis.select_candidates, fn candidate ->
          candidate.field == :language && candidate.option_provider.type == :domain
        end)

      assert language_candidate != nil
      assert language_candidate.option_provider.domain == :languages_domain
      assert language_candidate.option_provider.value_field == :language_id
      assert language_candidate.option_provider.display_field == :name
    end

    test "detects category association through Film Category join" do
      # Test that we can detect complex associations
      analysis =
        SchemaAnalyzer.analyze_schema(SelectoTest.Store.FilmCategory,
          include_associations: true
        )

      # Should detect film and category associations
      film_candidate = Enum.find(analysis.select_candidates, &(&1.field == :film))
      category_candidate = Enum.find(analysis.select_candidates, &(&1.field == :category))

      assert film_candidate != nil
      assert category_candidate != nil

      assert film_candidate.option_provider.type == :domain
      assert category_candidate.option_provider.type == :domain
    end
  end

  describe "Mix task integration" do
    test "can generate domain with dry run" do
      # We can't easily test the mix task directly, but we can test the underlying functionality
      domain_config = SchemaAnalyzer.generate_full_domain_config(SelectoTest.Store.Film)

      # Should generate a valid domain configuration
      assert is_map(domain_config)
      assert Map.has_key?(domain_config, :source)
      assert Map.has_key?(domain_config, :name)

      # Should include select options
      custom_columns = Map.get(domain_config, :custom_columns, %{})
      assert map_size(custom_columns) > 0

      # Each custom column should have proper structure
      Enum.each(custom_columns, fn {_field, config} ->
        assert Map.has_key?(config, :name)
        assert Map.has_key?(config, :option_provider)
        assert Map.get(config.option_provider, :type) in [:enum, :domain, :query]
      end)
    end
  end

  describe "Error handling and edge cases" do
    test "handles schema with no select candidates gracefully" do
      # Test with a simple schema that has no enums or associations
      analysis = SchemaAnalyzer.analyze_schema(SelectoTest.Store.Address)

      # Should not fail, just return empty candidates
      assert is_list(analysis.select_candidates)
      assert is_map(analysis.suggested_config)
    end

    test "handles invalid option provider gracefully" do
      invalid_provider = %{
        type: :enum,
        schema: NonExistentSchema,
        field: :nonexistent_field
      }

      assert {:error, _reason} = OptionProvider.load_options(invalid_provider)
    end

    test "validates provider configurations during schema analysis" do
      # The schema analyzer should generate valid provider configurations
      analysis = SchemaAnalyzer.analyze_schema(SelectoTest.Store.Film)

      # All generated providers should be valid
      Enum.each(analysis.select_candidates, fn candidate ->
        assert :ok = OptionProvider.validate_provider(candidate.option_provider)
      end)
    end
  end

  describe "Custom column configuration integration" do
    test "can add select options to existing domain configuration" do
      # Test that we can enhance an existing domain with select options
      base_domain = %{
        source: %{
          source_table: "test_table",
          primary_key: :id,
          fields: [:id, :name, :status],
          redact_fields: [],
          columns: %{
            id: %{type: :integer},
            name: %{type: :string},
            status: %{type: :string}
          },
          associations: %{}
        },
        schemas: %{},
        name: "Test Domain",
        joins: %{}
      }

      # Add select options configuration
      enhanced_domain =
        Map.put(base_domain, :custom_columns, %{
          "status" => %{
            name: "Status",
            option_provider: %{
              type: :static,
              values: ["active", "inactive", "pending"]
            }
          }
        })

      # Verify the configuration is valid
      custom_columns = enhanced_domain.custom_columns
      assert Map.has_key?(custom_columns, "status")

      status_config = custom_columns["status"]
      assert :ok = OptionProvider.validate_provider(status_config.option_provider)

      # Should be able to load options
      assert {:ok, options} = OptionProvider.load_options(status_config.option_provider)
      assert length(options) == 3
    end
  end
end
