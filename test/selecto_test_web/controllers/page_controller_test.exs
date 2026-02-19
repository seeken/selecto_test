defmodule SelectoTestWeb.PageControllerTest do
  use SelectoTestWeb.ConnCase

  setup_all do
    domain = SelectoTest.PagilaDomainFilms.domain()
    # Get Postgrex connection options from Repo config and start connection
    repo_config = SelectoTest.Repo.config()

    postgrex_opts = [
      username: repo_config[:username],
      password: repo_config[:password],
      hostname: repo_config[:hostname],
      database: repo_config[:database],
      port: repo_config[:port] || 5432
    ]

    # Start a Postgrex connection process for Selecto to use
    {:ok, db_conn} = Postgrex.start_link(postgrex_opts)

    selecto = Selecto.configure(domain, db_conn)
    {:ok, domain: domain, selecto: selecto}
  end
end
