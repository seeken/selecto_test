defmodule DebugConfigIntegrationTest do
  use ExUnit.Case, async: true
  alias SelectoComponents.Debug.ConfigReader

  describe "Domain debug configurations" do
    test "PagilaDomain has debug_config defined and shows queries" do
      config = SelectoTest.PagilaDomain.debug_config()

      assert config.enabled == true
      assert config.show_query == true
      assert config.show_params == true
      assert config.show_timing == true
      assert config.format_sql == true
    end

    test "PagilaDomainFilms has debug_config defined and shows queries" do
      config = SelectoTest.PagilaDomainFilms.debug_config()

      assert config.enabled == true
      assert config.show_query == true
      assert config.show_params == true
      assert config.show_timing == true
      assert config.format_sql == true
    end

    test "ConfigReader can read PagilaDomain config" do
      config = ConfigReader.get_config(SelectoTest.PagilaDomain)

      assert config.enabled == true
      assert config.show_query == true
      assert Map.has_key?(config, :views)
    end

    test "ConfigReader can read PagilaDomainFilms config" do
      config = ConfigReader.get_config(SelectoTest.PagilaDomainFilms)

      assert config.enabled == true
      assert config.show_query == true
      assert Map.has_key?(config, :views)
    end

    test "ConfigReader provides view-specific config for aggregate view" do
      config = ConfigReader.get_view_config(SelectoTest.PagilaDomain, :aggregate)

      assert config.show_query == true
      assert config.show_timing == true
      assert config.show_row_count == true
    end

    test "ConfigReader provides view-specific config for detail view" do
      config = ConfigReader.get_view_config(SelectoTest.PagilaDomainFilms, :detail)

      assert config.show_query == true
      assert config.show_params == true
      assert config.show_row_count == true
    end
  end
end
