defmodule SelectoTest.Repo.Migrations.CreateExportedViews do
  use Ecto.Migration

  def change do
    create table(:exported_views) do
      add(:name, :string, null: false)
      add(:context, :string, null: false)
      add(:path, :string)
      add(:view_type, :string, null: false)
      add(:public_id, :string, null: false)
      add(:signature_version, :integer, null: false, default: 1)
      add(:cache_ttl_hours, :integer, null: false, default: 3)
      add(:ip_allowlist_text, :text)
      add(:snapshot_blob, :binary, null: false)
      add(:cache_blob, :binary)
      add(:cache_generated_at, :utc_datetime_usec)
      add(:cache_expires_at, :utc_datetime_usec)
      add(:last_execution_time_ms, :float)
      add(:last_row_count, :integer)
      add(:last_payload_bytes, :integer)
      add(:access_count, :integer, null: false, default: 0)
      add(:last_accessed_at, :utc_datetime_usec)
      add(:last_error, :text)
      add(:disabled_at, :utc_datetime_usec)
      add(:user_id, :string)

      timestamps(type: :utc_datetime_usec)
    end

    create(unique_index(:exported_views, [:public_id]))
    create(index(:exported_views, [:context]))
    create(index(:exported_views, [:context, :user_id]))
    create(index(:exported_views, [:cache_expires_at]))
  end
end
