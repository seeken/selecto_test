defmodule SelectoTest.ExportedViewContext do
  @moduledoc false

  @behaviour SelectoComponents.ExportedViews

  import Ecto.Query

  alias SelectoTest.ExportedView
  alias SelectoTest.Repo

  @impl true
  def list_exported_views(context, opts \\ []) do
    user_id = Keyword.get(opts, :user_id)

    ExportedView
    |> where([view], view.context == ^context)
    |> maybe_scope_user(user_id)
    |> order_by([view], desc: view.updated_at, asc: view.name)
    |> Repo.all()
  end

  @impl true
  def get_exported_view_by_public_id(public_id, _opts \\ []) do
    Repo.get_by(ExportedView, public_id: public_id)
  end

  @impl true
  def create_exported_view(attrs, opts \\ []) do
    attrs = maybe_put_user_id(attrs, Keyword.get(opts, :user_id))

    %ExportedView{}
    |> ExportedView.changeset(attrs)
    |> Repo.insert()
  end

  @impl true
  def update_exported_view(%ExportedView{} = view, attrs, _opts \\ []) do
    view
    |> ExportedView.changeset(attrs)
    |> Repo.update()
  end

  @impl true
  def delete_exported_view(%ExportedView{} = view, _opts \\ []) do
    Repo.delete(view)
  end

  defp maybe_scope_user(query, nil), do: query

  defp maybe_scope_user(query, user_id) do
    where(query, [view], view.user_id == ^user_id)
  end

  defp maybe_put_user_id(attrs, nil), do: attrs

  defp maybe_put_user_id(attrs, user_id) when is_map(attrs) do
    Map.put_new(attrs, :user_id, user_id)
  end
end
