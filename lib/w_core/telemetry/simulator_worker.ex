defmodule WCore.Telemetry.SimulatorWorker do
  use GenServer

  alias WCore.Telemetry.DigitalTwin
  alias WCore.Telemetry.IngestServer

  @moduledoc """
  Worker que simula a operação contínua da Planta 42.

  Mantém um conjunto de Gêmeos Digitais em memória e os evolui
  a cada intervalo, injetando os eventos no IngestServer como se
  fossem sensores físicos reais.

  Implementa Simulação de Monte Carlo — cada ciclo aplica
  transições de estado probabilísticas e ruído gaussiano nas
  métricas, gerando dados realistas sem precisar de hardware.
  """

  # Intervalo entre cada ciclo de simulação (2 segundos)
  @intervalo_ms 2_000

  # Máquinas simuladas na Planta 42
  @maquinas [
    {1, "Torno CNC #1", "Setor A"},
    {2, "Torno CNC #2", "Setor A"},
    {3, "Prensa Hidráulica #1", "Setor B"},
    {4, "Prensa Hidráulica #2", "Setor B"},
    {5, "Compressor Industrial", "Setor C"},
    {6, "Esteira Principal", "Setor C"},
    {7, "Bomba Centrífuga #1", "Setor D"},
    {8, "Bomba Centrífuga #2", "Setor D"},
    {9, "Forno Industrial", "Setor E"},
    {10, "Robô Soldador", "Setor E"}
  ]

  # --- API Pública ---

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "Retorna o estado atual de todos os gêmeos digitais."
  def estado_atual do
    GenServer.call(__MODULE__, :estado_atual)
  end

  @doc "Força uma falha em uma máquina específica (para demonstração)."
  def forcar_falha(node_id) do
    GenServer.cast(__MODULE__, {:forcar_falha, node_id})
  end

  @doc "Recupera uma máquina específica (para demonstração)."
  def forcar_recuperacao(node_id) do
    GenServer.cast(__MODULE__, {:forcar_recuperacao, node_id})
  end

  # --- Callbacks OTP ---

  @impl true
  def init(_opts) do
    # Inicializa os gêmeos digitais
    gemeos =
      @maquinas
      |> Enum.map(fn {id, nome, local} ->
        {id, DigitalTwin.novo(id, nome, local)}
      end)
      |> Map.new()

    # Agenda o primeiro ciclo
    agendar_ciclo()

    {:ok, %{gemeos: gemeos, ciclo: 0}}
  end

  @impl true
  def handle_call(:estado_atual, _from, state) do
    {:reply, state.gemeos, state}
  end

  @impl true
  def handle_cast({:forcar_falha, node_id}, state) do
    gemeos =
      Map.update!(state.gemeos, node_id, fn twin ->
        %{twin | estado: :critico, ciclos_no_estado: 0}
      end)

    {:noreply, %{state | gemeos: gemeos}}
  end

  @impl true
  def handle_cast({:forcar_recuperacao, node_id}, state) do
    gemeos =
      Map.update!(state.gemeos, node_id, fn twin ->
        %{twin | estado: :recuperando, ciclos_no_estado: 0}
      end)

    {:noreply, %{state | gemeos: gemeos}}
  end

  @impl true
  def handle_info(:simular, state) do

    gemeos =
      Map.new(state.gemeos, fn {id, twin} ->
        novo_twin = DigitalTwin.evoluir(twin)

        IngestServer.ingest(
          id,
          DigitalTwin.status(novo_twin),
          DigitalTwin.payload(novo_twin)
        )

        {id, novo_twin}
      end)

    agendar_ciclo()

    {:noreply, %{state | gemeos: gemeos, ciclo: state.ciclo + 1}}
  end

  # --- Funções Privadas ---

  defp agendar_ciclo do
    Process.send_after(self(), :simular, @intervalo_ms)
  end
end
