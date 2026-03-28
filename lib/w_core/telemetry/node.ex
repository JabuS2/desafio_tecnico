defmodule WCore.Telemetry.Node do
  use Ecto.Schema
  import Ecto.Changeset

  @moduledoc """
  Schema do nó sensor cadastrado na Planta 42.
  Representa um dispositivo físico com identificador único e localização.
  """

  schema "nodes" do
    field :machine_identifier, :string
    field :location, :string

    has_one :metrics, WCore.Telemetry.NodeMetrics

    timestamps()
  end

  def changeset(node, attrs) do
    node
    |> cast(attrs, [:machine_identifier, :location])
    |> validate_required([:machine_identifier, :location])
    |> unique_constraint(:machine_identifier)
  end
end
