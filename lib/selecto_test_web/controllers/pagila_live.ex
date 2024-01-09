defmodule SelectoTestWeb.PagilaLive do
  use SelectoTestWeb, :live_view

  use SelectoComponents.Form
  ###

  @impl true
  def mount(_params, _session, socket) do
    {domain, path} =
      case socket.assigns.live_action do
        :index -> {SelectoTest.PagilaDomain.actors_domain(), "/pagila"}
        #:stores -> {SelectoTest.PagilaDomain.stores_domain(), "/pagila_stores"}
        :films -> {SelectoTest.PagilaDomainFilms.domain(), "/pagila_films"}
      end

    selecto = Selecto.configure(SelectoTest.Repo, domain)

    views = [
      {:aggregate, SelectoComponents.Views.Aggregate, "Aggregate View", %{drill_down: :detail}},
      {:detail, SelectoComponents.Views.Detail, "Detail View", %{}}
      # {:graph, SelectoComponents.Views.Graph, "Graph View", %{}},
    ]

    state = get_initial_state(views, selecto)

    saved_views = SelectoTest.PagilaDomain.get_view_names( path )

    socket =
      assign(socket,
        show_view_configurator: false,
        views: views,
        my_path: path,
        saved_view_module: SelectoTest.PagilaDomain,
        saved_view_context: path,

        ### For saved view links
        path: path,
        available_saved_views: saved_views
      )

    {:ok, assign(socket, state)}
  end

  @impl true
  def handle_event("toggle_show_view_configurator", _par, socket) do
    {:noreply, assign(socket, show_view_configurator: !socket.assigns.show_view_configurator)}
  end

  @doc """
  Test Domain
  """
end
