defmodule SelectoTestWeb.Router do
  use SelectoTestWeb, :router

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_live_flash)
    plug(:put_root_layout, {SelectoTestWeb.Layouts, :root})
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
  end

  pipeline :api do
    plug(:accepts, ["json"])
  end

  # The canonical Selecto API negotiates its own media types (JSON, OpenAPI,
  # CSV, TSV, XLSX), so it skips the :api pipeline's `accepts` check.
  pipeline :selecto_canonical do
  end

  scope "/", SelectoTestWeb do
    pipe_through(:browser)

    live("/", PagilaLive, :index)
    live("/pagila", PagilaLive, :index)
    live("/pagila_stores", PagilaLive, :stores)
    live("/pagila_films", PagilaLive, :films)
    live("/pagila/film/:film_id", PagilaFilmLive, :index)

    # Selecto Documentation
    live("/docs/selecto-system/*path", DocsLive)
  end

  # The canonical Selecto API and remote_query.explorer.v1 for the Pagila
  # Explorer domains (SelectoTest.CanonicalApi).
  scope "/api/selecto/canonical", SelectoTestWeb do
    pipe_through(:selecto_canonical)

    match(:*, "/*path", SelectoCanonicalController, :dispatch)
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:selecto_test, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through(:browser)

      live_dashboard("/dashboard",
        metrics: SelectoTestWeb.Telemetry,
        additional_pages: [
          selecto: SelectoTestWeb.LiveDashboard.SelectoPage
        ]
      )

      forward("/mailbox", Plug.Swoosh.MailboxPreview)
    end
  end
end
