# Universal Database Support Plan for Selecto

**Version:** 3.0.0  
**Date:** 2025-09-03  
**Status:** Active  
**Supersedes:** prior MySQL/MSSQL draft plan (removed)

## Executive Summary

This plan outlines a comprehensive strategy for extending Selecto to support multiple database systems through **separate, independently publishable adapter packages**. Each database adapter will be its own Hex package (e.g., `selecto_db_mysql`, `selecto_db_mssql`, `selecto_db_sqlite`) that can be maintained, versioned, and distributed independently. This approach ensures the core Selecto library remains lightweight while allowing the community to contribute and maintain database-specific adapters.

## Package Architecture

### Core Package
- **Package Name:** `selecto` (existing)
- **Responsibility:** Core query building, adapter interface, common functionality
- **Database Support:** PostgreSQL built-in for backward compatibility
- **Size:** Minimal, no heavy dependencies

### Database Adapter Packages
Each adapter is a separate Hex package that can be independently:
- Developed and maintained
- Versioned and released
- Installed only when needed
- Community contributed

#### Official Adapters (Maintained by Selecto Team)
1. **selecto_db_mysql** - MySQL/MariaDB adapter
2. **selecto_db_mssql** - Microsoft SQL Server adapter  
3. **selecto_db_sqlite** - SQLite adapter
4. **selecto_db_oracle** - Oracle Database adapter

#### Community Adapters
5. **selecto_db_cockroach** - CockroachDB adapter
6. **selecto_db_duckdb** - DuckDB adapter
7. **selecto_db_clickhouse** - ClickHouse adapter
8. **selecto_db_redshift** - Amazon Redshift adapter
9. **selecto_db_bigquery** - Google BigQuery adapter
10. **selecto_db_snowflake** - Snowflake adapter

### Package Structure Example

```
# selecto_db_mysql/
├── lib/
│   ├── selecto_db_mysql.ex              # Main module
│   ├── selecto_db_mysql/
│   │   ├── adapter.ex                   # Implements Selecto.Database.Adapter
│   │   ├── connection.ex                # MySQL connection management
│   │   ├── dialect.ex                   # MySQL SQL dialect
│   │   ├── types.ex                     # Type mappings
│   │   ├── features.ex                  # Feature capabilities
│   │   └── query_builder.ex             # MySQL-specific query building
│   └── mix/
│       └── tasks/
│           └── selecto.mysql.setup.ex   # Setup tasks
├── mix.exs                               # Package definition
├── README.md                             # Documentation
├── LICENSE                               # Apache 2.0 or MIT
└── test/
    └── selecto_db_mysql_test.exs
```

### Installation & Usage

```elixir
# mix.exs - Application using MySQL
def deps do
  [
    {:selecto, "~> 1.0"},
    {:selecto_db_mysql, "~> 1.0"},  # Only if using MySQL
    {:myxql, "~> 0.6"}               # MySQL driver
  ]
end

# config/config.exs
config :my_app, :selecto,
  adapter: Selecto.DB.MySQL,  # Module from selecto_db_mysql
  connection: [
    hostname: "localhost",
    username: "root",
    password: "secret",
    database: "myapp_dev"
  ]

# Usage in code
selecto = Selecto.configure(
  MyApp.Store.Film,
  adapter: Selecto.DB.MySQL,
  connection: Application.get_env(:my_app, :selecto)[:connection]
)
```

## Universal Architecture Design

### 1. Database Adapter Interface v2.0

```elixir
defmodule Selecto.Database.Adapter do
  @moduledoc """
  Universal database adapter specification for Selecto.
  All database integrations must implement this behavior.
  """
  
  @type connection :: any()
  @type query_result :: %{
    rows: [[any()]],
    columns: [String.t()],
    num_rows: non_neg_integer(),
    metadata: map()
  }
  
  # Lifecycle Management
  @callback initialize(opts :: keyword()) :: {:ok, map()} | {:error, term()}
  @callback connect(config :: map()) :: {:ok, connection()} | {:error, term()}
  @callback disconnect(connection()) :: :ok
  @callback ping(connection()) :: :ok | {:error, term()}
  @callback checkout(pool :: pid()) :: {:ok, connection()} | {:error, term()}
  @callback checkin(pool :: pid(), connection()) :: :ok
  
  # Query Execution
  @callback execute(connection(), query :: String.t(), params :: list(), opts :: keyword()) :: 
    {:ok, query_result()} | {:error, term()}
  @callback prepare(connection(), name :: String.t(), query :: String.t()) :: 
    {:ok, prepared_query :: any()} | {:error, term()}
  @callback execute_prepared(connection(), prepared_query :: any(), params :: list()) :: 
    {:ok, query_result()} | {:error, term()}
  
  # Transaction Management
  @callback transaction(connection(), fun :: function(), opts :: keyword()) :: 
    {:ok, any()} | {:error, term()} | {:rollback, term()}
  @callback begin(connection(), opts :: keyword()) :: {:ok, connection()} | {:error, term()}
  @callback commit(connection()) :: :ok | {:error, term()}
  @callback rollback(connection()) :: :ok | {:error, term()}
  @callback savepoint(connection(), name :: String.t()) :: :ok | {:error, term()}
  
  # SQL Dialect
  @callback dialect() :: module()
  @callback quote_identifier(String.t()) :: String.t()
  @callback quote_string(String.t()) :: String.t()
  @callback parameter_placeholder(index :: pos_integer()) :: String.t()
  @callback limit_syntax() :: :limit_offset | :top | :fetch_first | :rownum
  
  # Capabilities Declaration
  @callback capabilities() :: %{required(atom()) => boolean() | map()}
  @callback supports?(feature :: atom()) :: boolean()
  @callback version_requirement() :: String.t() | nil
  
  # Type System
  @callback type_map() :: %{elixir_type :: atom() => db_type :: String.t()}
  @callback cast_in(value :: any(), type :: atom()) :: any()
  @callback cast_out(value :: any(), type :: atom()) :: any()
  
  # Introspection
  @callback list_tables(connection(), schema :: String.t() | nil) :: 
    {:ok, [String.t()]} | {:error, term()}
  @callback describe_table(connection(), table :: String.t(), schema :: String.t() | nil) :: 
    {:ok, table_info :: map()} | {:error, term()}
  @callback table_exists?(connection(), table :: String.t(), schema :: String.t() | nil) :: 
    boolean()
    
  # Performance & Optimization
  @callback explain(connection(), query :: String.t(), opts :: keyword()) :: 
    {:ok, explanation :: String.t() | map()} | {:error, term()}
  @callback analyze(connection(), table :: String.t()) :: :ok | {:error, term()}
  @callback optimize_query(query :: String.t(), metadata :: map()) :: String.t()
  
  # Streaming Support
  @callback stream(connection(), query :: String.t(), params :: list(), opts :: keyword()) :: 
    {:ok, stream :: Enumerable.t()} | {:error, term()}
  @callback cursor_declare(connection(), name :: String.t(), query :: String.t()) :: 
    :ok | {:error, term()}
  @callback cursor_fetch(connection(), name :: String.t(), count :: pos_integer()) :: 
    {:ok, query_result()} | {:error, term()}
  @callback cursor_close(connection(), name :: String.t()) :: :ok | {:error, term()}
end
```

### 2. SQL Dialect System

```elixir
defmodule Selecto.Database.Dialect do
  @moduledoc """
  SQL dialect specification for different databases
  """
  
  defstruct [
    :name,
    :identifier_quote,
    :string_quote,
    :parameter_style,
    :limit_style,
    :boolean_style,
    :case_sensitivity,
    :null_ordering,
    :features,
    :functions,
    :operators,
    :reserved_words
  ]
  
  @type parameter_style :: :numbered | :question | :named | :at_named | :colon_named
  @type limit_style :: :limit_offset | :top | :fetch_first | :rownum | :row_number
  @type boolean_style :: :true_false | :one_zero | :yes_no | :t_f
  
  # Dialect Definitions
  def postgresql do
    %__MODULE__{
      name: "PostgreSQL",
      identifier_quote: "\"",
      string_quote: "'",
      parameter_style: :numbered,  # $1, $2
      limit_style: :limit_offset,
      boolean_style: :true_false,
      case_sensitivity: :preserve,
      null_ordering: :nulls_last,
      features: %{
        cte: true,
        recursive_cte: true,
        window_functions: true,
        lateral_joins: true,
        full_outer_join: true,
        arrays: true,
        json: true,
        full_text_search: true,
        materialized_views: true,
        table_inheritance: true,
        listen_notify: true
      }
    }
  end
  
  def mysql do
    %__MODULE__{
      name: "MySQL",
      identifier_quote: "`",
      string_quote: "'",
      parameter_style: :question,  # ?
      limit_style: :limit_offset,
      boolean_style: :one_zero,
      case_sensitivity: :lowercase,
      null_ordering: :nulls_first,
      features: %{
        cte: {">= 8.0", true},
        recursive_cte: {">= 8.0", true},
        window_functions: {">= 8.0", true},
        lateral_joins: {">= 8.0.14", true},
        full_outer_join: false,
        arrays: false,
        json: true,
        full_text_search: true,
        materialized_views: false
      }
    }
  end
  
  def sqlite do
    %__MODULE__{
      name: "SQLite",
      identifier_quote: "\"",
      string_quote: "'",
      parameter_style: :question,  # ? or ?NNN or :name
      limit_style: :limit_offset,
      boolean_style: :one_zero,
      case_sensitivity: :preserve,
      null_ordering: :nulls_first,
      features: %{
        cte: true,
        recursive_cte: true,
        window_functions: {">= 3.25", true},
        lateral_joins: false,
        full_outer_join: false,  # Can be emulated
        arrays: false,
        json: {">= 3.9", true},
        full_text_search: true,  # FTS5 extension
        materialized_views: false,
        in_memory: true,
        attach_databases: true
      }
    }
  end
  
  def mssql do
    %__MODULE__{
      name: "SQL Server",
      identifier_quote: "[",
      string_quote: "'",
      parameter_style: :at_named,  # @param1
      limit_style: :top,  # Also supports OFFSET FETCH
      boolean_style: :one_zero,
      case_sensitivity: :configurable,
      null_ordering: :nulls_first,
      features: %{
        cte: true,
        recursive_cte: true,
        window_functions: true,
        lateral_joins: true,  # via CROSS APPLY / OUTER APPLY
        full_outer_join: true,
        arrays: false,
        json: {">= 2016", true},
        full_text_search: true,
        materialized_views: true,  # Indexed views
        temporal_tables: {">= 2016", true}
      }
    }
  end
  
  def oracle do
    %__MODULE__{
      name: "Oracle",
      identifier_quote: "\"",
      string_quote: "'",
      parameter_style: :colon_named,  # :param1
      limit_style: :rownum,  # Also supports FETCH FIRST
      boolean_style: :one_zero,
      case_sensitivity: :uppercase,
      null_ordering: :nulls_last,
      features: %{
        cte: true,
        recursive_cte: true,
        window_functions: true,
        lateral_joins: {">= 12c", true},
        full_outer_join: true,
        arrays: false,  # Has nested tables/VARRAYs
        json: {">= 12c", true},
        full_text_search: true,  # Oracle Text
        materialized_views: true,
        flashback: true,
        partitioning: true
      }
    }
  end
end
```

### 3. Feature Compatibility Matrix

```elixir
defmodule Selecto.Database.Features do
  @moduledoc """
  Feature compatibility and translation layer
  """
  
  @features %{
    # Core SQL Features
    select: %{required: true, all: true},
    insert: %{required: true, all: true},
    update: %{required: true, all: true},
    delete: %{required: true, all: true},
    joins: %{required: true, all: true},
    subqueries: %{required: true, all: true},
    
    # Advanced Joins
    inner_join: %{all: true},
    left_join: %{all: true},
    right_join: %{all: true},
    full_outer_join: %{
      postgresql: true,
      mysql: false,
      sqlite: false,  # Can be emulated
      mssql: true,
      oracle: true
    },
    cross_join: %{all: true},
    lateral_join: %{
      postgresql: true,
      mysql: {version: ">= 8.0.14"},
      sqlite: false,
      mssql: :cross_apply,  # Different syntax
      oracle: {version: ">= 12c"}
    },
    
    # Window Functions
    window_functions: %{
      postgresql: true,
      mysql: {version: ">= 8.0"},
      sqlite: {version: ">= 3.25"},
      mssql: true,
      oracle: true
    },
    
    # CTEs
    common_table_expressions: %{
      postgresql: true,
      mysql: {version: ">= 8.0"},
      sqlite: true,
      mssql: true,
      oracle: true
    },
    recursive_cte: %{
      postgresql: true,
      mysql: {version: ">= 8.0"},
      sqlite: true,
      mssql: true,
      oracle: true
    },
    
    # Data Types
    arrays: %{
      postgresql: true,
      mysql: :json_arrays,
      sqlite: false,
      mssql: false,
      oracle: :nested_tables
    },
    json: %{
      postgresql: true,
      mysql: true,
      sqlite: {version: ">= 3.9"},
      mssql: {version: ">= 2016"},
      oracle: {version: ">= 12c"}
    },
    
    # Special Features
    full_text_search: %{
      postgresql: :tsvector,
      mysql: :fulltext,
      sqlite: :fts5,
      mssql: :fulltext,
      oracle: :oracle_text
    },
    
    # OLAP Features
    rollup: %{
      postgresql: true,
      mysql: true,
      sqlite: false,
      mssql: true,
      oracle: true
    },
    cube: %{
      postgresql: true,
      mysql: false,
      sqlite: false,
      mssql: true,
      oracle: true
    },
    grouping_sets: %{
      postgresql: true,
      mysql: false,
      sqlite: false,
      mssql: true,
      oracle: true
    }
  }
  
  def supported?(database, feature) do
    case get_in(@features, [feature, database]) do
      true -> true
      false -> false
      nil -> false
      {:version, requirement} -> check_version(database, requirement)
      value when is_atom(value) -> {:alternative, value}
    end
  end
  
  def emulation_available?(database, feature) do
    emulations()[{database, feature}] != nil
  end
  
  def emulate(database, feature, query_ast) do
    case emulations()[{database, feature}] do
      nil -> {:error, :not_emulatable}
      emulator -> emulator.(query_ast)
    end
  end
  
  defp emulations do
    %{
      # SQLite FULL OUTER JOIN emulation using UNION
      {:sqlite, :full_outer_join} => &emulate_full_outer_join_sqlite/1,
      
      # MySQL LATERAL JOIN emulation (pre-8.0.14)
      {:mysql, :lateral_join} => &emulate_lateral_join_mysql/1,
      
      # SQLite Window Functions emulation (pre-3.25)
      {:sqlite, :window_functions} => &emulate_window_functions_sqlite/1
    }
  end
end
```

### 4. Database-Specific Implementations

#### 4.1 SQLite Adapter

```elixir
defmodule Selecto.Adapters.SQLite do
  @behaviour Selecto.Database.Adapter
  
  @impl true
  def connect(config) do
    database = config[:database] || ":memory:"
    options = [
      journal_mode: config[:journal_mode] || :wal,
      cache_size: config[:cache_size] || -64000,  # 64MB
      foreign_keys: config[:foreign_keys] || :on,
      busy_timeout: config[:busy_timeout] || 5000
    ]
    
    case Exqlite.Sqlite3.open(database, options) do
      {:ok, conn} -> 
        # Initialize SQLite with optimal settings
        init_pragmas(conn, config)
        {:ok, conn}
      error -> error
    end
  end
  
  @impl true
  def capabilities do
    %{
      transactions: true,
      savepoints: true,
      prepared_statements: true,
      streaming: false,  # Limited streaming support
      concurrent_connections: :limited,  # WAL mode helps
      in_memory: true,
      attach_databases: true,
      encryption: {:extension, "SQLCipher"},
      backup: true,
      
      # SQL Features
      cte: true,
      recursive_cte: true,
      window_functions: {:version, ">= 3.25.0"},
      json: {:version, ">= 3.9.0"},
      full_text_search: {:extension, "FTS5"},
      rtree: {:extension, "R*Tree"},
      
      # Limitations
      alter_table: :limited,  # Can't drop columns
      foreign_keys: :configurable,
      right_join: false,
      full_outer_join: :emulated
    }
  end
  
  @impl true
  def dialect do
    Selecto.Database.Dialect.sqlite()
  end
  
  defp init_pragmas(conn, config) do
    pragmas = [
      "PRAGMA foreign_keys = ON",
      "PRAGMA journal_mode = WAL",
      "PRAGMA synchronous = NORMAL",
      "PRAGMA cache_size = -64000",
      "PRAGMA temp_store = MEMORY",
      "PRAGMA mmap_size = 30000000000"
    ]
    
    Enum.each(pragmas, fn pragma ->
      Exqlite.Sqlite3.execute(conn, pragma)
    end)
    
    # Load extensions if configured
    Enum.each(config[:extensions] || [], fn extension ->
      load_extension(conn, extension)
    end)
  end
  
  defp load_extension(conn, "fts5") do
    # FTS5 is usually built-in
    Exqlite.Sqlite3.execute(conn, "CREATE VIRTUAL TABLE IF NOT EXISTS fts5_test USING fts5(content)")
    Exqlite.Sqlite3.execute(conn, "DROP TABLE IF EXISTS fts5_test")
  end
end
```

#### 4.2 Oracle Adapter

```elixir
defmodule Selecto.Adapters.Oracle do
  @behaviour Selecto.Database.Adapter
  
  @impl true
  def connect(config) do
    connection_string = build_connection_string(config)
    
    # Using theoretical Oracle driver for Elixir
    case OracleDB.connect(
      hostname: config[:hostname],
      port: config[:port] || 1521,
      service_name: config[:service_name] || config[:sid],
      username: config[:username],
      password: config[:password],
      charset: config[:charset] || "AL32UTF8",
      prefetch_rows: config[:prefetch_rows] || 100
    ) do
      {:ok, conn} ->
        setup_session(conn, config)
        {:ok, conn}
      error -> 
        error
    end
  end
  
  @impl true
  def capabilities do
    %{
      transactions: true,
      savepoints: true,
      prepared_statements: true,
      streaming: true,
      concurrent_connections: true,
      
      # Oracle-specific
      pl_sql: true,
      packages: true,
      sequences: true,
      synonyms: true,
      materialized_views: true,
      flashback: true,
      partitioning: true,
      parallel_execution: true,
      result_cache: true,
      
      # Advanced SQL
      cte: true,
      recursive_cte: true,
      window_functions: true,
      model_clause: true,
      pivot_unpivot: true,
      lateral_joins: {:version, ">= 12c"},
      json: {:version, ">= 12c"},
      temporal_validity: {:version, ">= 12c"},
      
      # Analytics
      olap: true,
      data_mining: {:edition, :enterprise},
      advanced_analytics: {:edition, :enterprise}
    }
  end
  
  @impl true
  def parameter_placeholder(index) do
    ":#{index}"
  end
  
  @impl true
  def limit_syntax do
    # Oracle uses different syntax based on version
    :rownum  # Classic: WHERE ROWNUM <= n
    # Modern: OFFSET n ROWS FETCH NEXT m ROWS ONLY
  end
  
  defp setup_session(conn, config) do
    # Set session parameters
    session_params = [
      "ALTER SESSION SET NLS_DATE_FORMAT = 'YYYY-MM-DD HH24:MI:SS'",
      "ALTER SESSION SET NLS_TIMESTAMP_FORMAT = 'YYYY-MM-DD HH24:MI:SS.FF6'",
      "ALTER SESSION SET NLS_NUMERIC_CHARACTERS = '.,'",
      "ALTER SESSION SET TIME_ZONE = '#{config[:timezone] || "UTC"}'"
    ]
    
    Enum.each(session_params, fn param ->
      OracleDB.execute(conn, param)
    end)
  end
end
```

#### 4.3 DuckDB Adapter (Analytical Database)

```elixir
defmodule Selecto.Adapters.DuckDB do
  @behaviour Selecto.Database.Adapter
  
  @moduledoc """
  DuckDB adapter for analytical workloads.
  Optimized for OLAP queries and data analysis.
  """
  
  @impl true
  def connect(config) do
    database = config[:database] || ":memory:"
    
    case Duckdbex.open(database) do
      {:ok, db} ->
        conn = Duckdbex.connection(db)
        configure_duckdb(conn, config)
        {:ok, %{db: db, conn: conn}}
      error ->
        error
    end
  end
  
  @impl true
  def capabilities do
    %{
      # DuckDB-specific features
      columnar_storage: true,
      vectorized_execution: true,
      parallel_query: true,
      out_of_core: true,  # Can process data larger than RAM
      
      # File formats
      parquet: true,
      csv: true,
      json: true,
      excel: {:extension, "excel"},
      
      # SQL Features
      cte: true,
      recursive_cte: true,
      window_functions: true,
      grouping_sets: true,
      rollup: true,
      cube: true,
      pivot: true,
      unpivot: true,
      lateral_joins: true,
      asof_joins: true,  # Time-series joins
      
      # Analytics
      statistics: true,
      sampling: true,
      approximate_aggregates: true,
      
      # Data types
      arrays: true,
      maps: true,
      structs: true,
      unions: true,
      enums: true,
      
      # Special features
      time_travel: false,  # Not like Snowflake
      transactions: :limited,  # Read-only transactions
      acid: :limited
    }
  end
  
  @impl true
  def optimize_query(query, metadata) do
    # DuckDB-specific optimizations
    query
    |> optimize_for_columnar(metadata)
    |> add_parallel_hints(metadata)
    |> optimize_joins_for_analytics(metadata)
  end
  
  defp configure_duckdb(conn, config) do
    settings = [
      {"memory_limit", config[:memory_limit] || "4GB"},
      {"threads", config[:threads] || System.schedulers_online()},
      {"default_order", "ASC NULLS LAST"},
      {"enable_profiling", config[:profiling] || false},
      {"enable_progress_bar", config[:progress_bar] || false}
    ]
    
    Enum.each(settings, fn {key, value} ->
      Duckdbex.query(conn, "SET #{key} = '#{value}'")
    end)
  end
end
```

### 5. Query Translation Layer

```elixir
defmodule Selecto.Database.QueryTranslator do
  @moduledoc """
  Translates Selecto queries to database-specific SQL
  """
  
  def translate(query_ast, adapter) do
    query_ast
    |> normalize_query()
    |> apply_dialect_rules(adapter.dialect())
    |> handle_unsupported_features(adapter)
    |> optimize_for_database(adapter)
    |> generate_sql(adapter)
  end
  
  defp handle_unsupported_features(query_ast, adapter) do
    Enum.reduce(query_ast.features_used, query_ast, fn feature, ast ->
      case adapter.supports?(feature) do
        true -> 
          ast
        false -> 
          if adapter.emulation_available?(feature) do
            adapter.emulate(feature, ast)
          else
            raise Selecto.UnsupportedFeatureError, 
              feature: feature, 
              adapter: adapter.adapter_name()
          end
        {:alternative, alt} ->
          rewrite_with_alternative(ast, feature, alt)
      end
    end)
  end
  
  # SQL Dialect Translations
  defp translate_limit(ast, %{limit_style: :limit_offset}) do
    "LIMIT #{ast.limit} OFFSET #{ast.offset}"
  end
  
  defp translate_limit(ast, %{limit_style: :top}) do
    # SQL Server TOP clause
    "TOP #{ast.limit}"
  end
  
  defp translate_limit(ast, %{limit_style: :fetch_first}) do
    # ANSI SQL:2008
    "OFFSET #{ast.offset} ROWS FETCH FIRST #{ast.limit} ROWS ONLY"
  end
  
  defp translate_limit(ast, %{limit_style: :rownum}) do
    # Oracle classic
    "WHERE ROWNUM <= #{ast.limit}"
  end
  
  # Parameter binding translations
  defp translate_parameters(sql, params, %{parameter_style: :numbered}) do
    # PostgreSQL: $1, $2, etc.
    Enum.reduce(Enum.with_index(params, 1), sql, fn {_param, idx}, acc ->
      String.replace(acc, "?", "$#{idx}", global: false)
    end)
  end
  
  defp translate_parameters(sql, _params, %{parameter_style: :question}) do
    # MySQL, SQLite: ? placeholders
    sql
  end
  
  defp translate_parameters(sql, params, %{parameter_style: :at_named}) do
    # SQL Server: @param1, @param2
    Enum.reduce(Enum.with_index(params, 1), sql, fn {_param, idx}, acc ->
      String.replace(acc, "?", "@param#{idx}", global: false)
    end)
  end
  
  defp translate_parameters(sql, params, %{parameter_style: :colon_named}) do
    # Oracle: :1, :2 or :param1
    Enum.reduce(Enum.with_index(params, 1), sql, fn {_param, idx}, acc ->
      String.replace(acc, "?", ":#{idx}", global: false)
    end)
  end
end
```

### 6. Connection Pool Management

```elixir
defmodule Selecto.Database.Pool do
  @moduledoc """
  Universal connection pooling for all database adapters
  """
  
  def child_spec(opts) do
    adapter = Keyword.fetch!(opts, :adapter)
    pool_size = Keyword.get(opts, :pool_size, 10)
    
    case adapter.pool_module() do
      :poolboy ->
        poolboy_spec(adapter, opts, pool_size)
      :db_connection ->
        db_connection_spec(adapter, opts, pool_size)
      :custom ->
        adapter.pool_spec(opts)
      :none ->
        # Single connection, no pooling (e.g., SQLite)
        single_connection_spec(adapter, opts)
    end
  end
  
  defp poolboy_spec(adapter, opts, pool_size) do
    :poolboy.child_spec(
      adapter.adapter_name(),
      [
        name: {:local, opts[:name] || adapter.adapter_name()},
        worker_module: adapter.worker_module(),
        size: pool_size,
        max_overflow: Keyword.get(opts, :max_overflow, 5)
      ],
      opts
    )
  end
end
```

### 7. Testing Strategy

```elixir
defmodule Selecto.Database.TestSuite do
  @moduledoc """
  Universal test suite for database adapters
  """
  
  defmacro __using__(adapter: adapter) do
    quote do
      use ExUnit.Case
      
      @adapter unquote(adapter)
      @tag :database
      
      describe "#{@adapter.adapter_name()} adapter" do
        test "connects successfully" do
          assert {:ok, conn} = @adapter.connect(test_config())
          assert @adapter.ping(conn) == :ok
        end
        
        test "executes basic queries" do
          {:ok, conn} = @adapter.connect(test_config())
          
          # Create table
          assert {:ok, _} = @adapter.execute(conn, 
            "CREATE TABLE test_table (id INTEGER PRIMARY KEY, name TEXT)", [])
          
          # Insert
          assert {:ok, _} = @adapter.execute(conn,
            "INSERT INTO test_table (id, name) VALUES (?, ?)", [1, "test"])
          
          # Select
          assert {:ok, %{rows: [[1, "test"]]}} = @adapter.execute(conn,
            "SELECT id, name FROM test_table WHERE id = ?", [1])
        end
        
        test "supports transactions" do
          if @adapter.supports?(:transactions) do
            {:ok, conn} = @adapter.connect(test_config())
            
            assert {:ok, _} = @adapter.transaction(conn, fn conn ->
              @adapter.execute(conn, "INSERT INTO test_table (id, name) VALUES (?, ?)", 
                [2, "transaction_test"])
            end)
          end
        end
        
        # Feature-specific tests
        for feature <- [:cte, :window_functions, :lateral_joins] do
          test "supports #{feature}" do
            if @adapter.supports?(unquote(feature)) do
              test_feature(unquote(feature))
            else
              skip "#{unquote(feature)} not supported"
            end
          end
        end
      end
    end
  end
end
```

### 8. Migration Path

#### Phase 1: Core Infrastructure (Weeks 1-2)
- [ ] Implement adapter behavior
- [ ] Create dialect system
- [ ] Build query translator
- [ ] Setup testing framework

#### Phase 2: Tier 1 Databases (Weeks 3-6)
- [ ] MySQL adapter
- [ ] SQLite adapter  
- [ ] SQL Server adapter
- [ ] Integration tests

#### Phase 3: Tier 2 Databases (Weeks 7-10)
- [ ] MariaDB adapter (fork MySQL)
- [ ] Oracle adapter
- [ ] CockroachDB adapter
- [ ] Amazon Redshift adapter

#### Phase 4: Analytical Databases (Weeks 11-14)
- [ ] DuckDB adapter
- [ ] ClickHouse adapter
- [ ] BigQuery adapter
- [ ] Snowflake adapter

#### Phase 5: Production Hardening (Weeks 15-16)
- [ ] Performance optimization
- [ ] Connection pool tuning
- [ ] Error handling improvements
- [ ] Documentation

### 9. Configuration Examples

```elixir
# PostgreSQL (current)
config :my_app, :selecto,
  adapter: Selecto.Adapters.PostgreSQL,
  hostname: "localhost",
  username: "postgres",
  password: "postgres",
  database: "my_app_dev"

# MySQL
config :my_app, :selecto_mysql,
  adapter: Selecto.Adapters.MySQL,
  hostname: "localhost",
  port: 3306,
  username: "root",
  password: "mysql",
  database: "my_app_dev",
  charset: "utf8mb4"

# SQLite
config :my_app, :selecto_sqlite,
  adapter: Selecto.Adapters.SQLite,
  database: "priv/data/my_app.db",
  journal_mode: :wal,
  foreign_keys: :on

# Oracle
config :my_app, :selecto_oracle,
  adapter: Selecto.Adapters.Oracle,
  hostname: "oracle.example.com",
  port: 1521,
  service_name: "ORCL",
  username: "system",
  password: "oracle",
  charset: "AL32UTF8"

# DuckDB (Analytical)
config :my_app, :selecto_analytics,
  adapter: Selecto.Adapters.DuckDB,
  database: ":memory:",
  memory_limit: "8GB",
  threads: 8

# Multi-database setup
config :my_app, :selecto_multi,
  default: :postgresql,
  databases: %{
    postgresql: [adapter: Selecto.Adapters.PostgreSQL, ...],
    mysql: [adapter: Selecto.Adapters.MySQL, ...],
    analytics: [adapter: Selecto.Adapters.DuckDB, ...]
  }
```

### 10. Usage Examples

```elixir
# Auto-detect adapter from config
selecto = Selecto.new(:my_database)

# Explicit adapter
selecto = Selecto.new(adapter: Selecto.Adapters.MySQL, config: [...])

# Multi-database queries
selecto_pg = Selecto.new(:postgresql)
selecto_mysql = Selecto.new(:mysql)

# Copy data between databases
results = selecto_pg
|> Selecto.from("users")
|> Selecto.select([:id, :name, :email])
|> Selecto.execute()

selecto_mysql
|> Selecto.insert_all("users", results)
|> Selecto.execute()

# Use database-specific features
selecto
|> Selecto.from("products")
|> Selecto.select([:name, :price])
|> Selecto.where_feature(:full_text_search, "description", "laptop")
|> Selecto.execute()

# Feature detection
if Selecto.supports?(selecto, :window_functions) do
  selecto
  |> Selecto.select([{:row_number, [], partition_by: :category}])
  |> Selecto.execute()
else
  # Fallback logic
end
```

## Benefits of This Architecture

1. **True Plug-and-Play**: Adding a new database requires only implementing the adapter behavior
2. **Zero Core Changes**: The Selecto core remains database-agnostic
3. **Feature Detection**: Applications can detect and adapt to database capabilities
4. **Performance**: Database-specific optimizations are encapsulated in adapters
5. **Testing**: Universal test suite ensures consistency across databases
6. **Migration**: Easy to switch databases or use multiple databases

## Implementation Priority

### Must Have (MVP)
1. Adapter behavior definition
2. MySQL adapter
3. SQLite adapter
4. Query translation layer
5. Basic feature detection

### Should Have
1. SQL Server adapter
2. Oracle adapter
3. Connection pooling
4. Transaction support
5. Comprehensive testing

### Nice to Have
1. DuckDB for analytics
2. ClickHouse integration
3. Cloud database support (BigQuery, Redshift)
4. Automatic feature emulation
5. Query optimization hints

## Conclusion

This universal database support plan provides a robust, extensible foundation for Selecto to work with virtually any SQL database. The architecture prioritizes:

- **Modularity**: Each adapter is self-contained
- **Extensibility**: New databases can be added without breaking changes
- **Performance**: Database-specific optimizations are preserved
- **Compatibility**: Feature detection and emulation provide maximum compatibility
- **Developer Experience**: Consistent API across all databases

The phased implementation approach allows for incremental delivery while maintaining stability of the core system.
