defmodule SelectoTest.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Telemetry supervisor
      SelectoTestWeb.Telemetry,
      # Start the Ecto repository
      SelectoTest.Repo,
      SelectoTest.JoinConfigStore,
      # Start the PubSub system
      {Phoenix.PubSub, name: SelectoTest.PubSub},
      # Start Finch
      {Finch, name: SelectoTest.Finch},
      # Start the Endpoint (http/https)
      SelectoTestWeb.Endpoint
      # Start a worker by calling: SelectoTest.Worker.start_link(arg)
      # {SelectoTest.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: SelectoTest.Supervisor]
    result = Supervisor.start_link(children, opts)

    # Install Selecto performance hooks after the supervisor starts
    if Code.ensure_loaded?(Selecto.Performance.Hooks) do
      Selecto.Performance.Hooks.install_default_hooks(
        slow_query_threshold: 100,
        auto_explain_threshold: 500
      )
    end

    result
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    SelectoTestWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
