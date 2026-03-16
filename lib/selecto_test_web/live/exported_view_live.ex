defmodule SelectoTestWeb.ExportedViewLive do
  use SelectoTestWeb, :live_view

  @impl true
  def mount(params, session, socket) do
    SelectoComponents.ExportedViews.EmbedLive.mount(
      params,
      session,
      socket,
      adapter: SelectoTest.ExportedViewContext,
      endpoint: SelectoTestWeb.Endpoint
    )
  end

  @impl true
  def handle_info(msg, socket) do
    SelectoComponents.ExportedViews.EmbedLive.handle_info(msg, socket)
  end

  @impl true
  def handle_event(event, params, socket) do
    SelectoComponents.ExportedViews.EmbedLive.handle_event(event, params, socket)
  end

  @impl true
  def render(assigns) do
    SelectoComponents.ExportedViews.EmbedLive.render(assigns)
  end
end
