defmodule SelectoTest.MixProject do
  use Mix.Project

  def project do
    [
      app: :selecto_test,
      version: "0.3.2",
      elixir: "~> 1.18",
      compilers: [:phoenix_live_view] ++ Mix.compilers(),
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      listeners: [Phoenix.CodeReloader],
      # Test configuration
      test_coverage: [tool: ExCoveralls]
    ]
  end

  def cli do
    [
      preferred_envs: [
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
      # {:phoenix_html_helpers, "~> 1.0"},

      {:phoenix_live_reload, "~> 1.6", only: :dev},
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
      selecto_dep(),
      selecto_db_postgresql_dep(),
      selecto_components_dep(),
      selecto_mix_dep(),
      {:timex, "~> 3.7.9"},
      {:uuid, "~> 1.1"},
      {:kino, "~> 0.7.0"},
      {:tidewave, "~> 0.5.5", only: :dev},
      {:excoveralls, "~> 0.18", only: :test},
      {:earmark, "~> 1.4"}
    ]
    |> Kernel.++(selecto_postgis_deps())
  end

  defp selecto_dep do
    if use_local_ecosystem?() do
      {:selecto, path: "../selecto", override: true}
    else
      {:selecto, ">= 0.4.0 and < 0.5.0", override: true}
    end
  end

  defp selecto_db_postgresql_dep do
    if use_local_ecosystem?() do
      {:selecto_db_postgresql, path: "../selecto_db_postgresql", override: true}
    else
      {:selecto_db_postgresql, ">= 0.4.0 and < 0.5.0", override: true}
    end
  end

  defp selecto_postgis_deps do
    if enable_postgis?() do
      [selecto_postgis_dep()]
    else
      []
    end
  end

  defp selecto_postgis_dep do
    if use_local_ecosystem?() do
      {:selecto_postgis, path: "../selecto_postgis", override: true}
    else
      {:selecto_postgis, "~> 0.1", override: true}
    end
  end

  defp enable_postgis? do
    use_local_ecosystem?() || truthy_env?(System.get_env("SELECTO_ENABLE_POSTGIS"))
  end

  defp selecto_components_dep do
    if use_local_ecosystem?() do
      {:selecto_components, path: "../selecto_components", override: true}
    else
      {:selecto_components, ">= 0.4.0 and < 0.5.0", override: true}
    end
  end

  defp selecto_mix_dep do
    if use_local_ecosystem?() do
      {:selecto_mix, path: "../selecto_mix", only: [:dev, :test]}
    else
      {:selecto_mix, "~> 0.4.0", only: [:dev, :test]}
    end
  end

  defp use_local_ecosystem? do
    truthy_env?(System.get_env("SELECTO_ECOSYSTEM_USE_LOCAL"))
  end

  defp truthy_env?(value) when value in ["1", "true", "TRUE", "yes", "YES", "on", "ON"],
    do: true

  defp truthy_env?(_), do: false

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
      "test.setup": ["ecto.create --quiet", "ecto.migrate --quiet"],
      "test.full": ["test.setup", "test"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["compile", "tailwind default", "esbuild default"],
      "assets.deploy": [
        "compile",
        "tailwind default --minify",
        "esbuild default --minify",
        "phx.digest"
      ]
    ]
  end
end
