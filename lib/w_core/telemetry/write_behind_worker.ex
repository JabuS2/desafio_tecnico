defmodule WCore.Telemetry.WriteBehindWorker do
  use GenServer

  alias WCore.Telemetry.Cache
  alias WCore.Telemetry.NodeMetrics
  alias WCore.Repo

  @moduledoc """
  Worker assíncrono responsável por persistir o estado do cache ETS
  no SQLite a cada intervalo de tempo (Write-Behind Pattern).

  Varre toda a tabela ETS e realiza upsert em lote na tabela
  node_metrics, garantindo que o banco reflita o último estado
  conhecido de cada sensor sem bloquear o fluxo de ingestão.
  """

  # Intervalo entre cada ciclo de persistência (5 segundos)
  @flush_interval :timer.seconds(5)

  # --- API Pública ---

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  # --- Callbacks OTP ---

  @impl true
  def init(_opts) do
    # Agenda o primeiro ciclo de flush
    schedule_flush()
    {:ok, %{}}
  end

  @impl true
  def handle_info(:flush, state) do
    flush_to_db()
    schedule_flush()
    {:noreply, state}
  end

  # --- Funções Privadas ---

  defp schedule_flush do
    Process.send_after(self(), :flush, @flush_interval)
  end

  defp flush_to_db do
    records = Cache.all()

    Enum.each(records, fn {node_id, status, event_count, last_payload, timestamp} ->
      last_seen_at =
        timestamp
        |> DateTime.truncate(:second)

      attrs = %{
        node_id: node_id,
        status: status,
        total_events_processed: event_count,
        last_payload: last_payload,
        last_seen_at: last_seen_at
      }

      case Repo.get_by(NodeMetrics, node_id: node_id) do
        nil ->
          %NodeMetrics{}
          |> NodeMetrics.changeset(attrs)
          |> Repo.insert()

        existing ->
          existing
          |> NodeMetrics.changeset(attrs)
          |> Repo.update()
      end
    end)
  end
end
