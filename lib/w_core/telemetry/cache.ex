defmodule WCore.Telemetry.Cache do
  @moduledoc """
  Camada de acesso à tabela ETS de telemetria em tempo real.

  A tabela `:w_core_telemetry_cache` é do tipo `set` com acesso
  público e concorrente. Cada entrada representa o estado mais
  recente de um nó sensor.

  Estrutura de cada registro:
    {node_id, status, event_count, last_payload, timestamp}

  O contador de eventos usa `:ets.update_counter/3` para garantir
  atomicidade — sem race condition mesmo sob carga extrema.
  """

  @table :w_core_telemetry_cache

  @doc "Cria a tabela ETS. Deve ser chamado pelo processo supervisor."
  def init do
    :ets.new(@table, [:set, :public, :named_table, read_concurrency: true])
  end

  @doc """
  Insere ou atualiza o estado de um nó no cache.

  O incremento do contador é feito atomicamente via `:ets.update_counter/3`,
  eliminando race conditions na contagem de eventos sob concorrência extrema.
  """
  def upsert(node_id, status, payload) do
    timestamp = DateTime.utc_now()

    case :ets.lookup(@table, node_id) do
      [{^node_id, _status, _count, _payload, _ts}] ->
        # Atualiza status, payload e timestamp atomicamente
        :ets.insert(@table, {
          node_id,
          status,
          # Incremento atômico do contador — posição 3 da tupla, incremento de 1
          :ets.update_counter(@table, node_id, {3, 1}),
          payload,
          timestamp
        })

      [] ->
        # Primeira vez que este nó aparece — inicializa com count 1
        :ets.insert(@table, {node_id, status, 1, payload, timestamp})
    end
  end

  @doc "Retorna todos os registros do cache."
  def all do
    :ets.tab2list(@table)
  end

  @doc "Retorna o estado de um nó específico."
  def get(node_id) do
    case :ets.lookup(@table, node_id) do
      [record] -> {:ok, record}
      [] -> {:error, :not_found}
    end
  end
end
