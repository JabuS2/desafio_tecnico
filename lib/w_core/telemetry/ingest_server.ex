defmodule WCore.Telemetry.IngestServer do
  use GenServer

  alias WCore.Telemetry.Cache

  @moduledoc """
  GenServer responsável por receber os pulsos dos sensores
  e atualizar o cache ETS de forma assíncrona e segura.

  Estrutura esperada do payload:
    %{
      temperatura: float(),   # °C
      pressao: float(),       # bar
      vibracao: float(),      # mm/s
      rpm: integer(),         # rotações por minuto
      voltagem: float(),      # V
      corrente: float()       # A
    }
  """

  # --- API Pública ---

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Envia um pulso de um sensor para processamento.
  Chamada assíncrona (cast) para não bloquear o sensor.
  """
  def ingest(node_id, status, payload) do
    GenServer.cast(__MODULE__, {:ingest, node_id, status, payload})
  end

  # --- Callbacks OTP ---

  @impl true
  def init(_opts) do
    {:ok, %{}}
  end

  @impl true
  def handle_cast({:ingest, node_id, status, payload}, state) do
    payload_normalizado = normalizar_payload(payload)

    Cache.upsert(node_id, status, payload_normalizado)

    Phoenix.PubSub.broadcast(
      WCore.PubSub,
      "telemetry:updates",
      {:node_update, node_id, status}
    )

    {:noreply, state}
  end

  # --- Funções Privadas ---

  defp normalizar_payload(payload) do
    %{
      temperatura: Map.get(payload, :temperatura, 0.0),
      pressao:     Map.get(payload, :pressao, 0.0),
      vibracao:    Map.get(payload, :vibracao, 0.0),
      rpm:         Map.get(payload, :rpm, 0),
      voltagem:    Map.get(payload, :voltagem, 0.0),
      corrente:    Map.get(payload, :corrente, 0.0)
    }
  end
end
