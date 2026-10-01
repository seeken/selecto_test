defmodule SelectoTest.PagilaData do
  @moduledoc """
  Pagila sample data for tests that assert real rows.

  `ensure_loaded!/0` loads `priv/sql/pagila-data.sql` into the test database
  when its actor, film, and film_actor tables are empty, as
  `priv/repo/seeds.exs` does, and raises when the data is still missing.

  `rows!/2` runs a plain SQL query through the repo, so a test can ask the
  same question its Selecto query asks and compare the rows.
  """

  alias SelectoTest.Repo

  @doc "Make sure the Pagila sample data is in the test database."
  @spec ensure_loaded!() :: :ok
  def ensure_loaded! do
    Ecto.Adapters.SQL.Sandbox.unboxed_run(Repo, fn ->
      unless loaded?() do
        output = load()

        unless loaded?() do
          raise "Pagila sample data is not loaded into #{Repo.config()[:database]}: " <>
                  String.slice(output, 0, 500)
        end
      end
    end)

    :ok
  end

  @doc "Run `sql` with `params` through the repo and return its rows."
  @spec rows!(String.t(), list()) :: [list()]
  def rows!(sql, params \\ []), do: Repo.query!(sql, params).rows

  defp loaded? do
    %{rows: [counts]} =
      Repo.query!(
        "select (select count(*) from actor), (select count(*) from film), " <>
          "(select count(*) from film_actor)"
      )

    Enum.all?(counts, &(&1 > 0))
  end

  defp load do
    config = Repo.config()
    data_file = Application.app_dir(:selecto_test, "priv/sql/pagila-data.sql")

    args = [
      "-h",
      config[:hostname] || "localhost",
      "-p",
      to_string(config[:port] || 5432),
      "-U",
      config[:username] || "postgres",
      "-d",
      config[:database],
      "-q",
      "-f",
      data_file
    ]

    {output, _status} =
      System.cmd("psql", args,
        env: [{"PGPASSWORD", config[:password] || ""}],
        stderr_to_stdout: true
      )

    output
  rescue
    error in ErlangError -> "psql could not be run: #{Exception.message(error)}"
  end
end
