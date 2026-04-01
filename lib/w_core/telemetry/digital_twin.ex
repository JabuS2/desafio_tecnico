defmodule WCore.Telemetry.DigitalTwin do
  @moduledoc """
  Gêmeo Digital de uma máquina industrial.

  Cada máquina tem um estado interno que evolui ao longo do tempo
  seguindo heurísticas baseadas em física industrial.

  Estados possíveis:
  - :normal     → operação dentro dos parâmetros
  - :aquecendo  → temperatura subindo progressivamente
  - :critico    → limites ultrapassados, risco de falha
  - :falhando   → falha iminente
  - :recuperando → retornando aos parâmetros normais após intervenção
  """

  defstruct [
    :id,
    :nome,
    :localizacao,
    estado: :normal,
    temperatura: 65.0,
    pressao: 1.0,
    vibracao: 0.2,
    rpm: 1450,
    voltagem: 220.0,
    corrente: 12.0,
    ciclos_no_estado: 0
  ]

  @doc "Cria um novo gêmeo digital com valores iniciais aleatórios."
  def novo(id, nome, localizacao) do
    %__MODULE__{
      id: id,
      nome: nome,
      localizacao: localizacao,
      temperatura: 60.0 + :rand.uniform(20) * 1.0,
      pressao: 0.8 + :rand.uniform(4) * 0.1,
      vibracao: 0.1 + :rand.uniform(3) * 0.1,
      rpm: 1200 + :rand.uniform(500),
      voltagem: 215.0 + :rand.uniform(10) * 1.0,
      corrente: 10.0 + :rand.uniform(5) * 1.0
    }
  end

  @doc """
  Evolui o estado do gêmeo digital aplicando Monte Carlo.

  Cada ciclo aplica:
  1. Transição de estado baseada em probabilidade
  2. Variação de métricas baseada no estado atual
  3. Ruído gaussiano para realismo
  """
  def evoluir(%__MODULE__{} = twin) do
    twin
    |> transicionar_estado()
    |> atualizar_metricas()
    |> adicionar_ruido()
    |> Map.update!(:ciclos_no_estado, &(&1 + 1))
  end

  @doc "Converte o estado interno para o status do sistema."
  def status(%__MODULE__{estado: :normal}), do: "ok"
  def status(%__MODULE__{estado: :aquecendo}), do: "warning"
  def status(%__MODULE__{estado: :critico}), do: "critical"
  def status(%__MODULE__{estado: :falhando}), do: "critical"
  def status(%__MODULE__{estado: :recuperando}), do: "warning"

  @doc "Converte as métricas para o payload do IngestServer."
  def payload(%__MODULE__{} = twin) do
    %{
      temperatura: Float.round(twin.temperatura, 1),
      pressao: Float.round(twin.pressao, 2),
      vibracao: Float.round(twin.vibracao, 2),
      rpm: twin.rpm,
      voltagem: Float.round(twin.voltagem, 1),
      corrente: Float.round(twin.corrente, 1),
      estado: Atom.to_string(twin.estado)
    }
  end

  # --- Transições de Estado (Monte Carlo) ---

  # Normal: pequena chance de começar a aquecer
  defp transicionar_estado(%{estado: :normal, ciclos_no_estado: c} = twin) do
    cond do
      :rand.uniform(100) <= 5 -> %{twin | estado: :aquecendo, ciclos_no_estado: 0}
      true -> twin
    end
  end

  # Aquecendo: pode piorar ou se estabilizar
  defp transicionar_estado(%{estado: :aquecendo, ciclos_no_estado: c} = twin) do
    cond do
      c > 10 and :rand.uniform(100) <= 30 -> %{twin | estado: :critico, ciclos_no_estado: 0}
      :rand.uniform(100) <= 10 -> %{twin | estado: :normal, ciclos_no_estado: 0}
      true -> twin
    end
  end

  # Crítico: pode falhar ou começar a recuperar
  defp transicionar_estado(%{estado: :critico, ciclos_no_estado: c} = twin) do
    cond do
      c > 5 and :rand.uniform(100) <= 20 -> %{twin | estado: :falhando, ciclos_no_estados: 0}
      :rand.uniform(100) <= 15 -> %{twin | estado: :recuperando, ciclos_no_estado: 0}
      true -> twin
    end
  end

  # Falhando: começa a recuperar após alguns ciclos
  defp transicionar_estado(%{estado: :falhando, ciclos_no_estado: c} = twin) do
    cond do
      c > 3 -> %{twin | estado: :recuperando, ciclos_no_estado: 0}
      true -> twin
    end
  end

  # Recuperando: volta ao normal gradualmente
  defp transicionar_estado(%{estado: :recuperando, ciclos_no_estado: c} = twin) do
    cond do
      c > 8 -> %{twin | estado: :normal, ciclos_no_estado: 0}
      true -> twin
    end
  end

  # --- Atualização de Métricas por Estado ---

  defp atualizar_metricas(%{estado: :normal} = twin) do
    %{twin |
      temperatura: max(60.0, twin.temperatura - 0.5),
      pressao: max(0.8, twin.pressao - 0.02),
      vibracao: max(0.1, twin.vibracao - 0.05),
      rpm: max(1200, twin.rpm - 5)
    }
  end

  defp atualizar_metricas(%{estado: :aquecendo} = twin) do
    %{twin |
      temperatura: min(95.0, twin.temperatura + 1.5),
      pressao: min(3.5, twin.pressao + 0.05),
      vibracao: min(2.0, twin.vibracao + 0.1),
      rpm: min(2200, twin.rpm + 20)
    }
  end

  defp atualizar_metricas(%{estado: :critico} = twin) do
    %{twin |
      temperatura: min(110.0, twin.temperatura + 2.5),
      pressao: min(5.0, twin.pressao + 0.15),
      vibracao: min(4.0, twin.vibracao + 0.3),
      rpm: min(2800, twin.rpm + 50),
      corrente: min(25.0, twin.corrente + 0.5)
    }
  end

  defp atualizar_metricas(%{estado: :falhando} = twin) do
    %{twin |
      temperatura: min(120.0, twin.temperatura + 3.0),
      pressao: min(6.0, twin.pressao + 0.3),
      vibracao: min(6.0, twin.vibracao + 0.8),
      rpm: max(0, twin.rpm - 200),
      voltagem: max(180.0, twin.voltagem - 5.0),
      corrente: min(30.0, twin.corrente + 2.0)
    }
  end

  defp atualizar_metricas(%{estado: :recuperando} = twin) do
    %{twin |
      temperatura: max(65.0, twin.temperatura - 2.0),
      pressao: max(1.0, twin.pressao - 0.1),
      vibracao: max(0.2, twin.vibracao - 0.2),
      rpm: max(1450, twin.rpm - 50)
    }
  end

  # --- Ruído Gaussiano (Monte Carlo) ---

  defp adicionar_ruido(twin) do
    %{twin |
      temperatura: twin.temperatura + ruido(0.5),
      pressao: twin.pressao + ruido(0.05),
      vibracao: twin.vibracao + ruido(0.02),
      rpm: twin.rpm + round(ruido(10)),
      voltagem: twin.voltagem + ruido(0.3),
      corrente: twin.corrente + ruido(0.2)
    }
  end

  defp ruido(amplitude) do
    soma = Enum.reduce(1..6, 0, fn _, acc -> acc + (:rand.uniform() - 0.5) end)
    soma * amplitude
  end
end
