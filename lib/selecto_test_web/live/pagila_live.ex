defmodule SelectoTestWeb.PagilaLive do
  use SelectoTestWeb, :live_view

  use SelectoComponents.Form
  ###

  @impl true
  def mount(_params, _session, socket) do
    {module, domain, path} =
      case socket.assigns.live_action do
        :index ->
          {SelectoTest.PagilaDomain, SelectoTest.PagilaDomain.actors_domain(), "/pagila"}

        # Fallback to actors for now
        :stores ->
          {SelectoTest.PagilaDomain, SelectoTest.PagilaDomain.actors_domain(), "/pagila_stores"}

        :films ->
          {SelectoTest.PagilaDomainFilms, SelectoTest.PagilaDomainFilms.domain(), "/pagila_films"}
      end

    # Configure Selecto to use the main Repo connection pool
    selecto = Selecto.configure(domain, SelectoTest.Repo)

    views = [
      {:aggregate, SelectoComponents.Views.Aggregate, "Aggregate View", %{drill_down: :detail}},
      {:detail, SelectoComponents.Views.Detail, "Detail View", %{}},
      {:graph, SelectoComponents.Views.Graph, "Graph View", %{}}
    ]

    state = get_initial_state(views, selecto)

    saved_views = module.get_view_names(path)

    socket =
      assign(socket,
        show_view_configurator: false,
        views: views,
        my_path: path,
        saved_view_module: SelectoTest.PagilaDomain,
        saved_view_context: path,

        # New saved view configs with view type separation
        saved_view_config_module: module,
        # In a real app, this would come from the session
        current_user_id: "demo_user",

        # Filter sets adapter
        filter_sets_adapter: SelectoTest.FilterSets,
        # In a real app, this would come from the session
        user_id: "demo_user",
        domain: path,

        ### For saved view links
        path: path,
        available_saved_views: saved_views,

        # Enable modal detail view (opt-in feature)
        enable_modal_detail: true,
        show_detail_modal: false,
        modal_detail_data: nil
      )

    {:ok, assign(socket, state)}
  end

  @impl true
  def handle_event("toggle_show_view_configurator", _par, socket) do
    {:noreply, assign(socket, show_view_configurator: !socket.assigns.show_view_configurator)}
  end

  @impl true
  def handle_info({:apply_filter_set, filter_set}, socket) do
    # Convert the saved filters from the filter set into the view_config format
    filters =
      filter_set.filters
      |> Enum.map(fn {uuid, filter_data} ->
        {uuid, "filters", filter_data}
      end)

    # Update the view_config with the loaded filters
    view_config = Map.put(socket.assigns.view_config, :filters, filters)

    {:noreply,
     socket
     |> assign(view_config: view_config)
     |> assign(page_title: "View: #{filter_set.name}")}
  end

  def handle_info({:apply_view_config, saved_config}, socket) do
    # Apply the loaded view configuration params
    # Convert string keys to atoms for consistency
    params = saved_config.params || %{}
    params = deep_atomize_keys(params)

    # Get the current view type
    view_type = socket.assigns.view_config.view_mode || "detail"
    view_type_atom = String.to_existing_atom(view_type)

    # Extract the saved configuration for this view type
    saved_view_config = Map.get(params, view_type_atom, Map.get(params, view_type, %{}))

    # For detail view, we need to update the selecto object with the columns
    socket =
      case view_type do
        "detail" ->
          # Get the selected columns from the saved config
          selected = Map.get(saved_view_config, :selected, [])
          order_by = Map.get(saved_view_config, :order_by, [])

          # Update the Selecto object with the new columns
          selecto = socket.assigns.selecto

          # Convert the selected format to what Selecto expects
          columns =
            Enum.map(selected, fn
              [uuid, field, data] ->
                Map.merge(data, %{"uuid" => uuid, "field" => field})

              {uuid, field, data} ->
                Map.merge(data, %{"uuid" => uuid, "field" => field})
            end)

          # Apply columns to Selecto - extract just the field names
          fields =
            Enum.map(columns, fn col ->
              Map.get(col, "field", Map.get(col, :field))
            end)

          # Clear existing selections and apply new ones
          selecto = %{selecto | set: %{selecto.set | selected: [], columns: []}}
          selecto = Selecto.select(selecto, fields)

          # Apply order by
          order_by_fields =
            Enum.map(order_by, fn
              [_uuid, field, data] ->
                dir = Map.get(data, "dir", "asc")
                {field, String.to_atom(dir)}

              {_uuid, field, data} ->
                dir = Map.get(data, :dir, "asc")
                {field, String.to_atom(dir)}
            end)

          selecto =
            case order_by_fields do
              [] -> selecto
              fields -> Selecto.order_by(selecto, fields)
            end

          assign(socket, selecto: selecto)

        _ ->
          socket
      end

    # Update the views section for this specific view type
    current_views = Map.get(socket.assigns.view_config, :views, %{})
    updated_views = Map.put(current_views, view_type_atom, saved_view_config)

    # Merge with existing view_config, preserving filters and other settings
    view_config = Map.put(socket.assigns.view_config, :views, updated_views)

    # Also update the columns in the main view_config for detail view
    view_config =
      case view_type do
        "detail" ->
          # Update columns to match what was loaded
          columns =
            Map.get(saved_view_config, :selected, [])
            |> Enum.map(fn
              [uuid, field, data] -> {uuid, field, data}
              item -> item
            end)

          Map.put(view_config, :columns, columns)

        _ ->
          view_config
      end

    # Force the Form component to re-render with the new view_config
    socket =
      socket
      |> assign(view_config: view_config)
      |> assign(page_title: "View: #{saved_config.name}")

    # Send a message to force update of the form with all necessary data
    send_update(SelectoComponents.Form,
      id: "config",
      view_config: view_config,
      selecto: socket.assigns.selecto,
      executed: socket.assigns.executed,
      views: socket.assigns.views
    )

    {:noreply, socket}
  end

  defp deep_atomize_keys(map) when is_map(map) do
    Map.new(map, fn
      {k, v} when is_binary(k) ->
        atom_key =
          try do
            String.to_existing_atom(k)
          rescue
            ArgumentError -> String.to_atom(k)
          end

        {atom_key, deep_atomize_keys(v)}

      {k, v} ->
        {k, deep_atomize_keys(v)}
    end)
  end

  defp deep_atomize_keys(list) when is_list(list) do
    Enum.map(list, &deep_atomize_keys/1)
  end

  defp deep_atomize_keys(value), do: value

  @doc """
  Test Domain
  """
end
