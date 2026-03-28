defmodule WCore.Telemetry.NodeMetrics do
  use Ecto.Schema
  import Ecto.Changeset

  @moduledoc """
  Schema de métricas consolidadas de um nó sensor.
  Armazena o último estado conhecido vindo da camada ETS.
  """

  schema "node_metrics" do
    field :status, :string, default: "unknown"
    field :total_events_processed, :integer, default: 0
    field :last_payload, :map
    field :last_seen_at, :utc_datetime

    belongs_to :node, WCore.Telemetry.Node

    timestamps()
  end

  def changeset(metrics, attrs) do
    metrics
    |> cast(attrs, [:status, :total_events_processed, :last_payload, :last_seen_at, :node_id])
    |> validate_required([:node_id, :status])
    |> unique_constraint(:node_id)
  end
end
