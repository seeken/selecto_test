defmodule SelectoTest.SavedViewContext do
  defmacro __using__(_opts \\ []) do
    quote do
      @behaviour SelectoComponents.SavedViews

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

      def decode_view(view) do
        ### give params to use for view
        view.params
      end
    end
  end
end
