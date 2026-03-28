defmodule WCore.Telemetry do
  @moduledoc """
  Contexto de Telemetria da Planta 42.

  Responsável por gerenciar o cadastro de nós (sensores)
  e suas métricas consolidadas.

  O fluxo de dados segue duas camadas:
  - Camada quente: ETS (leitura/escrita em memória, tempo real)
  - Camada fria: SQLite via Ecto (persistência, fonte de verdade)
  """
end
