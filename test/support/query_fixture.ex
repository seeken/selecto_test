defmodule SelectoTest.QueryFixture do
  @moduledoc false

  @adapter SelectoDBPostgreSQL.Adapter

  def configure(domain, opts \\ []) when is_map(domain) and is_list(opts) do
    adapter = Keyword.get(opts, :adapter, @adapter)
    runtime = Selecto.Runtime.Context.new(adapter, :compile_only, %{purpose: :sql_generation})

    Selecto.configure(
      domain,
      runtime,
      opts
      |> Keyword.put(:adapter, adapter)
      |> Keyword.put_new(:validate, false)
    )
  end

  def from_map(%Selecto{} = selecto), do: selecto

  def from_map(query) when is_map(query) do
    adapter = Map.get(query, :adapter, @adapter)

    %Selecto{
      adapter: adapter,
      runtime:
        Map.get_lazy(query, :runtime, fn ->
          Selecto.Runtime.Context.new(adapter, :compile_only, %{purpose: :sql_generation})
        end),
      connection: Map.get(query, :connection, :compile_only),
      domain: Map.get(query, :domain, %{}),
      config: Map.get(query, :config, %{}),
      set: Map.get(query, :set, %{}),
      extensions: Map.get(query, :extensions, []),
      tenant: Map.get(query, :tenant),
      policy: Map.get(query, :policy)
    }
  end

  def create_cte(name, query_builder, opts \\ []) when is_function(query_builder, 0) do
    Selecto.Advanced.CTE.create_cte(name, fn -> query_builder.() |> from_map() end, opts)
  end

  def create_recursive_cte(name, opts) when is_list(opts) do
    base_query = Keyword.fetch!(opts, :base_query)
    recursive_query = Keyword.fetch!(opts, :recursive_query)

    wrapped_opts =
      opts
      |> Keyword.put(:base_query, fn -> base_query.() |> from_map() end)
      |> Keyword.put(:recursive_query, fn cte -> recursive_query.(cte) |> from_map() end)

    Selecto.Advanced.CTE.create_recursive_cte(name, wrapped_opts)
  end
end
