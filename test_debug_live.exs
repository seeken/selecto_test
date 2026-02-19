# Test script to verify debug display in live view
# Run with: mix run test_debug_live.exs

alias SelectoTest.PagilaDomain
alias SelectoComponents.Form

# Simulate what happens in the LiveView
view_config = %{
  view_mode: "detail",
  group_by: [],
  aggregate: [],
  filters: [],
  columns: ["first_name", "last_name"]
}

# Simulate query results like they come from the query execution  
query_results = {
  List.duplicate(%{first_name: "John", last_name: "Doe"}, 200),
  ["first_name", "last_name"],
  []
}

last_query_info = %{
  sql: "SELECT first_name, last_name FROM actors",
  params: [],
  timing: 25.5
}

# Create assigns like they would be in the LiveView
assigns = %{
  domain_module: PagilaDomain,
  view_config: view_config,
  query_results: query_results,
  last_query_info: last_query_info,
  executed: true
}

IO.puts("Testing Debug Display with LiveView assigns")
IO.puts("============================================\n")

IO.puts("1. Assigns being passed:")
IO.puts("   executed: #{assigns.executed}")
IO.puts("   query_results tuple size: #{tuple_size(assigns.query_results)}")
{rows, _, _} = assigns.query_results
IO.puts("   Number of rows in query_results: #{length(rows)}")

IO.puts("\n2. Building debug data:")
debug_data = Form.build_debug_data(assigns)
IO.puts("   Debug data built: #{inspect(debug_data)}")

IO.puts("\n3. Testing ConfigReader.build_debug_info:")
alias SelectoComponents.Debug.ConfigReader
config = ConfigReader.get_view_config(PagilaDomain, :detail)
IO.puts("   Config for detail view: #{inspect(config)}")

debug_info = ConfigReader.build_debug_info(debug_data, config)
IO.puts("   Final debug_info: #{inspect(debug_info)}")

IO.puts("\n✅ Test completed")
IO.puts("If row_count is missing from debug_info, check that show_row_count is true in config")
