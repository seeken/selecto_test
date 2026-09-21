defmodule SelectoTestWeb.PagilaLive do
  use SelectoTestWeb, :live_view

  @impl true
  def mount(params, _session, socket) do
    {domain, title} =
      case socket.assigns.live_action do
        :index ->
          {SelectoTest.PagilaDomain.actors_domain(), "Pagila Actors"}

        :stores ->
          {SelectoTest.PagilaDomain.actors_domain(), "Pagila Stores"}

        :films ->
          {SelectoTest.PagilaDomainFilms.domain(), "Pagila Films"}
      end

    selecto = Selecto.configure(domain, SelectoTest.Repo)

    {:ok, assign(socket, selecto: selecto, page_title: title, params: params)}
  end
end
