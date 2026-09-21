defmodule SelectoTest.SavedViewContext do
  defmacro __using__(_opts \\ []) do
    quote do
      import Ecto.Query

      def get_view(name, context) do
        q =
          from v in SelectoTest.SavedView,
            where: ^context == v.context,
            where: ^name == v.name

        SelectoTest.Repo.one(q)
      end

      def save_view(name, context, params) do
        case get_view(name, context) do
          nil ->
            SelectoTest.Repo.insert!(%SelectoTest.SavedView{
              name: name,
              context: context,
              params: params
            })

          view ->
            update_view(view, params)
        end
      end

      def update_view(view, params) do
        {:ok, view} =
          SelectoTest.SavedView.changeset(view, %{params: params})
          |> SelectoTest.Repo.update()

        view
      end

      def get_view_names(context) do
        q =
          from v in SelectoTest.SavedView,
            select: v.name,
            where: ^context == v.context

        SelectoTest.Repo.all(q)
      end

      def list_views(context) do
        q =
          from v in SelectoTest.SavedView,
            where: ^context == v.context,
            order_by: [desc: v.updated_at, asc: v.name]

        SelectoTest.Repo.all(q)
      end

      def delete_view(name, context) do
        case get_view(name, context) do
          nil ->
            {:error, :not_found}

          view ->
            SelectoTest.Repo.delete(view)
        end
      end

      def rename_view(old_name, new_name, context) do
        trimmed_name = String.trim(new_name || "")

        cond do
          trimmed_name == "" ->
            {:error, :invalid_name}

          old_name == trimmed_name ->
            case get_view(old_name, context) do
              nil -> {:error, :not_found}
              view -> {:ok, view}
            end

          true ->
            case get_view(old_name, context) do
              nil ->
                {:error, :not_found}

              view ->
                if get_view(trimmed_name, context) do
                  {:error, :already_exists}
                else
                  view
                  |> SelectoTest.SavedView.changeset(%{name: trimmed_name})
                  |> SelectoTest.Repo.update()
                end
            end
        end
      end

      def decode_view(view) do
        ### give params to use for view
        view.params
      end
    end
  end
end
