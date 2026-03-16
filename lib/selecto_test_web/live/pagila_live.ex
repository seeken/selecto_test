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

    saved_views = load_saved_views(module, path)

    socket =
      assign(socket,
        show_view_configurator: false,
        views: views,
        my_path: path,
        saved_view_module: module,
        saved_view_context: path,
        exported_view_module: SelectoTest.ExportedViewContext,
        exported_view_context: path,
        exported_view_endpoint: SelectoTestWeb.Endpoint,
        exported_view_base_url: "/selecto/exported",

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
        saved_view_rename_target: nil,
        can_rename_saved_views: can_rename_saved_views?(module),
        can_delete_saved_views: can_delete_saved_views?(module),

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
  def handle_event("saved_views_refresh", _params, socket) do
    {:noreply, refresh_saved_views(socket)}
  end

  @impl true
  def handle_event("saved_view_begin_rename", %{"name" => name}, socket) do
    {:noreply, assign(socket, saved_view_rename_target: name)}
  end

  @impl true
  def handle_event("saved_view_cancel_rename", _params, socket) do
    {:noreply, assign(socket, saved_view_rename_target: nil)}
  end

  @impl true
  def handle_event("saved_view_delete", %{"name" => name}, socket) do
    module = socket.assigns.saved_view_module
    context = socket.assigns.saved_view_context

    cond do
      is_nil(module) or not function_exported?(module, :delete_view, 2) ->
        {:noreply, put_flash(socket, :error, "Delete is not supported for saved views")}

      true ->
        case module.delete_view(name, context) do
          {:ok, _deleted} ->
            socket =
              socket
              |> assign(saved_view_rename_target: nil)
              |> refresh_saved_views()
              |> maybe_remove_saved_view_from_url(name)
              |> put_flash(:info, "Deleted saved view '#{name}'")

            {:noreply, socket}

          {:error, :not_found} ->
            {:noreply,
             socket |> refresh_saved_views() |> put_flash(:error, "Saved view not found")}

          {:error, reason} ->
            {:noreply,
             put_flash(
               socket,
               :error,
               "Failed to delete saved view: #{format_saved_view_error(reason)}"
             )}
        end
    end
  end

  @impl true
  def handle_event(
        "saved_view_rename",
        %{"old_name" => old_name, "new_name" => new_name},
        socket
      ) do
    module = socket.assigns.saved_view_module
    context = socket.assigns.saved_view_context
    trimmed_name = String.trim(new_name || "")

    cond do
      trimmed_name == "" ->
        {:noreply, put_flash(socket, :error, "New saved view name cannot be empty")}

      String.match?(trimmed_name, ~r/[^a-zA-Z0-9_ ]/) ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "View name can only include letters, numbers, spaces, and underscore"
         )}

      trimmed_name == old_name ->
        {:noreply,
         socket
         |> assign(saved_view_rename_target: nil)
         |> put_flash(:info, "Saved view name unchanged")}

      is_nil(module) or not function_exported?(module, :rename_view, 3) ->
        {:noreply, put_flash(socket, :error, "Rename is not supported for saved views")}

      true ->
        Selecto.Helpers.check_safe_phrase(trimmed_name)

        case module.rename_view(old_name, trimmed_name, context) do
          {:ok, _renamed} ->
            socket =
              socket
              |> assign(saved_view_rename_target: nil)
              |> refresh_saved_views()
              |> maybe_replace_saved_view_in_url(old_name, trimmed_name)
              |> put_flash(:info, "Renamed '#{old_name}' to '#{trimmed_name}'")

            {:noreply, socket}

          {:error, :already_exists} ->
            {:noreply, put_flash(socket, :error, "A saved view with that name already exists")}

          {:error, :not_found} ->
            {:noreply,
             socket |> refresh_saved_views() |> put_flash(:error, "Saved view not found")}

          {:error, reason} ->
            {:noreply,
             put_flash(
               socket,
               :error,
               "Failed to rename saved view: #{format_saved_view_error(reason)}"
             )}
        end
    end
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

  @impl true
  def handle_info({:saved_view_saved, _name}, socket) do
    {:noreply, refresh_saved_views(socket)}
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

  defp refresh_saved_views(socket) do
    saved_views = load_saved_views(socket.assigns.saved_view_module, socket.assigns.path)
    assign(socket, available_saved_views: saved_views)
  end

  defp load_saved_views(nil, _context), do: []

  defp load_saved_views(module, context) do
    views =
      cond do
        function_exported?(module, :list_views, 1) ->
          module.list_views(context)

        function_exported?(module, :get_view_names, 1) ->
          module.get_view_names(context)

        true ->
          []
      end

    views
    |> Enum.map(&normalize_saved_view/1)
    |> Enum.sort_by(fn view ->
      {-saved_view_timestamp(view.updated_at), String.downcase(view.name)}
    end)
  end

  defp normalize_saved_view(view) when is_binary(view) do
    %{name: view, updated_at: nil}
  end

  defp normalize_saved_view(%{name: name} = view) do
    %{name: to_string(name), updated_at: Map.get(view, :updated_at)}
  end

  defp normalize_saved_view(%{"name" => name} = view) do
    %{name: to_string(name), updated_at: Map.get(view, "updated_at")}
  end

  defp normalize_saved_view(other) do
    %{name: to_string(other), updated_at: nil}
  end

  defp saved_view_timestamp(%DateTime{} = updated_at), do: DateTime.to_unix(updated_at)

  defp saved_view_timestamp(%NaiveDateTime{} = updated_at) do
    updated_at
    |> DateTime.from_naive!("Etc/UTC")
    |> DateTime.to_unix()
  end

  defp saved_view_timestamp(_), do: 0

  defp maybe_replace_saved_view_in_url(socket, old_name, new_name) do
    params = socket.assigns |> Map.get(:params, %{}) |> ensure_params_map()

    if Map.get(params, "saved_view") == old_name do
      patched_params = Map.put(params, "saved_view", new_name)
      push_patch(socket, to: build_path_with_params(socket.assigns.path, patched_params))
    else
      socket
    end
  end

  defp maybe_remove_saved_view_from_url(socket, deleted_name) do
    params = socket.assigns |> Map.get(:params, %{}) |> ensure_params_map()

    if Map.get(params, "saved_view") == deleted_name do
      patched_params = Map.delete(params, "saved_view")
      push_patch(socket, to: build_path_with_params(socket.assigns.path, patched_params))
    else
      socket
    end
  end

  defp build_path_with_params(path, params) do
    encoded =
      params
      |> Enum.reject(fn {_key, value} -> is_nil(value) or value == "" end)
      |> Enum.into(%{}, fn {key, value} -> {to_string(key), value} end)
      |> Plug.Conn.Query.encode()

    if encoded == "" do
      path
    else
      "#{path}?#{encoded}"
    end
  end

  defp saved_view_link(path, params, saved_view_name) do
    params = ensure_params_map(params)

    params
    |> Map.put("saved_view", saved_view_name)
    |> then(&build_path_with_params(path, &1))
  end

  defp saved_view_updated_label(%DateTime{} = updated_at) do
    updated_at
    |> Calendar.strftime("%Y-%m-%d %H:%M")
  end

  defp saved_view_updated_label(%NaiveDateTime{} = updated_at) do
    updated_at
    |> NaiveDateTime.to_string()
    |> String.slice(0, 16)
  end

  defp saved_view_updated_label(_), do: "Unknown"

  defp ensure_params_map(params) when is_map(params), do: params
  defp ensure_params_map(_params), do: %{}

  defp can_rename_saved_views?(module) when is_atom(module),
    do: function_exported?(module, :rename_view, 3)

  defp can_rename_saved_views?(_module), do: false

  defp can_delete_saved_views?(module) when is_atom(module),
    do: function_exported?(module, :delete_view, 2)

  defp can_delete_saved_views?(_module), do: false

  defp format_saved_view_error(reason) when is_binary(reason), do: reason

  defp format_saved_view_error(%Ecto.Changeset{} = changeset) do
    changeset
    |> Ecto.Changeset.traverse_errors(fn {message, _opts} -> message end)
    |> Enum.map(fn {field, messages} -> "#{field} #{Enum.join(messages, ", ")}" end)
    |> Enum.join("; ")
  end

  defp format_saved_view_error(reason), do: inspect(reason)

  @doc """
  Test Domain
  """
end
