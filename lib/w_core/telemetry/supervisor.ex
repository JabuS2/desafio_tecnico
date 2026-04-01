defmodule WCore.Telemetry.Supervisor do
  use Supervisor

  alias WCore.Telemetry.Cache
  alias WCore.Telemetry.IngestServer
  alias WCore.Telemetry.WriteBehindWorker
  alias WCore.Telemetry.SimulatorWorker

  @moduledoc """
  Supervisor responsável por orquestrar os processos do
  sistema de telemetria em tempo real.

  Estratégia `one_for_one`: se um processo filho falhar,
  apenas ele é reiniciado — os demais continuam operando.

  Ordem de inicialização importa:
  1. Cache (ETS) — deve existir antes de qualquer outro processo
  2. IngestServer — depende do Cache para gravar
  3. WriteBehindWorker — depende do Cache para ler
  """

  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    Cache.init()

    children = [
      IngestServer,
      WriteBehindWorker,
      SimulatorWorker
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

end
