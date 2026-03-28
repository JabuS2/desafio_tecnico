defmodule WCore.Telemetry.IngestServer do
  use GenServer

  alias WCore.Telemetry.Cache

  @moduledoc """
  GenServer responsável por receber os pulsos dos sensores
  e atualizar o cache ETS de forma síncrona e segura.

  É o ponto de entrada único para eventos de telemetria,
  garantindo que não haja condição de corrida na contagem
  de eventos por nó.
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
    Cache.upsert(node_id, status, payload)

    Phoenix.PubSub.broadcast(
      WCore.PubSub,
      "telemetry:#{node_id}",
      {:node_update, node_id, status}
    )

    {:noreply, state}
  end
end
