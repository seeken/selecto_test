defmodule SelectoTest.ExportedView do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  @view_types ~w(detail aggregate graph map)
  @ttl_hours [3, 6, 12]

  schema "exported_views" do
    field(:name, :string)
    field(:context, :string)
    field(:path, :string)
    field(:view_type, :string)
    field(:public_id, :string)
    field(:signature_version, :integer, default: 1)
    field(:cache_ttl_hours, :integer, default: 3)
    field(:ip_allowlist_text, :string)
    field(:snapshot_blob, :binary)
    field(:cache_blob, :binary)
    field(:cache_generated_at, :utc_datetime_usec)
    field(:cache_expires_at, :utc_datetime_usec)
    field(:last_execution_time_ms, :float)
    field(:last_row_count, :integer)
    field(:last_payload_bytes, :integer)
    field(:access_count, :integer, default: 0)
    field(:last_accessed_at, :utc_datetime_usec)
    field(:last_error, :string)
    field(:disabled_at, :utc_datetime_usec)
    field(:user_id, :string)

    timestamps(type: :utc_datetime_usec)
  end

  @doc false
  def changeset(exported_view, attrs) do
    exported_view
    |> cast(attrs, [
      :name,
      :context,
      :path,
      :view_type,
      :public_id,
      :signature_version,
      :cache_ttl_hours,
      :ip_allowlist_text,
      :snapshot_blob,
      :cache_blob,
      :cache_generated_at,
      :cache_expires_at,
      :last_execution_time_ms,
      :last_row_count,
      :last_payload_bytes,
      :access_count,
      :last_accessed_at,
      :last_error,
      :disabled_at,
      :user_id
    ])
    |> validate_required([
      :name,
      :context,
      :view_type,
      :public_id,
      :snapshot_blob,
      :cache_ttl_hours
    ])
    |> validate_length(:name, min: 1, max: 255)
    |> validate_inclusion(:view_type, @view_types)
    |> validate_inclusion(:cache_ttl_hours, @ttl_hours)
    |> unique_constraint(:public_id)
  end
end
