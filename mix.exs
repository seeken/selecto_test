defmodule SelectoTest.MixProject do
  use Mix.Project

  def project do
    [
      app: :selecto_test,
      version: "0.3.0",
      elixir: "~> 1.17",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      listeners: [Phoenix.CodeReloader],
      # Test configuration
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ]
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {SelectoTest.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:phoenix, "~> 1.8.0", override: true},
      {:phoenix_ecto, "~> 4.6"},
      {:postgrex, ">= 0.0.0"},
      {:phoenix_html, "~> 4.0"},
      {:ecto_sql, "~> 3.12"},
      #{:phoenix_html_helpers, "~> 1.0"},

      {:phoenix_live_reload, "~> 1.5"},
      {:phoenix_live_view, "~> 1.1.4", override: true},
      {:lazy_html, "~> 0.1.0"},
      {:heroicons, "~> 0.5", override: true},
      {:floki, ">= 0.30.0", only: :test},
      {:phoenix_live_dashboard, "~> 0.8.7"},
      {:esbuild, "~> 0.8", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.2.0", runtime: Mix.env() == :dev},
      {:swoosh, "~> 1.3"},
      {:finch, "~> 0.13"},
      {:telemetry_metrics, "~> 0.6"},
      {:telemetry_poller, "~> 1.0"},
      {:gettext, "~> 0.20"},
      {:jason, "~> 1.2"},
      {:bandit, "~> 1.5"},

      {:selecto, path: "./vendor/selecto", override: true},
      {:selecto_components, path: "./vendor/selecto_components", override: true},
      {:selecto_dome, path: "./vendor/selecto_dome"},
      {:selecto_cone, path: "./vendor/selecto_cone"},
      {:selecto_mix, path: "./vendor/selecto_mix", only: [:dev, :test]},
      {:selecto_dev, path: "./vendor/selecto_dev", only: :dev},
      {:selecto_db_sqlite, path: "./vendor/selecto_db_sqlite", optional: true},
      {:selecto_db_mysql, path: "./vendor/selecto_db_mysql", optional: true},
      {:exqlite, "~> 0.13"},
      {:timex, "~> 3.7.9"},
      {:uuid, "~> 1.1"},
      {:kino, "~> 0.7.0"},
      {:tidewave, "~> 0.2", only: :dev},
      {:excoveralls, "~> 0.18", only: :test},
      {:earmark, "~> 1.4"},
      {:phoenix_playground, "~> 0.1.7"}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "ecto.setup", "assets.setup", "assets.build"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["compile", "tailwind default", "esbuild default"],
      "assets.deploy": ["compile", "tailwind default --minify", "esbuild default --minify", "phx.digest"]
    ]
  end
end
