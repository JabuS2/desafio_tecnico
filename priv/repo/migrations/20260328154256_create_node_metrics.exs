defmodule WCore.Repo.Migrations.CreateNodeMetrics do
  use Ecto.Migration

  def change do
    create table(:node_metrics) do
      add :node_id, references(:nodes, on_delete: :delete_all), null: false
      add :status, :string, null: false, default: "unknown"
      add :total_events_processed, :integer, null: false, default: 0
      add :last_payload, :map
      add :last_seen_at, :utc_datetime

      timestamps()
    end

    create unique_index(:node_metrics, [:node_id])
  end
end
