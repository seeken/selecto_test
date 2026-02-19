# Test script to verify debug display is working
# Run with: mix run test_debug_display.exs

alias SelectoTest.PagilaDomain
alias SelectoComponents.Debug.ConfigReader
alias SelectoComponents.Form

IO.puts("Testing Debug Display Configuration")
IO.puts("=====================================\n")

# Test ConfigReader
IO.puts("1. Testing ConfigReader.debug_enabled?")
enabled = ConfigReader.debug_enabled?(PagilaDomain, :detail)
IO.puts("   Debug enabled for PagilaDomain detail view: #{enabled}")

config = ConfigReader.get_view_config(PagilaDomain, :detail)
IO.puts("   Config: #{inspect(config, pretty: true)}")

# Test build_debug_data function
IO.puts("\n2. Testing Form.build_debug_data")

test_assigns = %{
  query_results: {[%{id: 1, name: "Test"}, %{id: 2, name: "Test2"}], [:id, :name], []},
  last_query_info: %{
    sql: "SELECT * FROM actors",
    params: [],
    timing: 15.3
  }
}

debug_data = Form.build_debug_data(test_assigns)
IO.puts("   Debug data: #{inspect(debug_data, pretty: true)}")
IO.puts("   Row count: #{debug_data.row_count}")

# Test with nil query_results
test_assigns2 = %{
  query_results: nil,
  last_query_info: %{
    sql: "SELECT * FROM actors",
    params: [],
    timing: 10.0
  }
}

debug_data2 = Form.build_debug_data(test_assigns2)
IO.puts("\n3. Testing with nil query_results")
IO.puts("   Debug data: #{inspect(debug_data2, pretty: true)}")
IO.puts("   Row count: #{debug_data2.row_count}")

IO.puts("\n✅ Test completed")
