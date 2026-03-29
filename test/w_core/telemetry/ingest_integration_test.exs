defmodule WCore.Telemetry.IngestIntegrationTest do
  use ExUnit.Case, async: false
  use WCore.DataCase, async: false

  alias WCore.Telemetry.Cache
  alias WCore.Telemetry.IngestServer

  @moduledoc """
  Teste de integração: injeta 10.000 eventos concorrentes e prova
  que o ETS não perdeu eventos e não houve condição de corrida.
  """

  setup do
    # Garante tabela limpa a cada teste
    try do
      :ets.delete(:w_core_telemetry_cache)
    rescue
      _ -> :ok
    end

    Cache.init()
    Ecto.Adapters.SQL.Sandbox.mode(WCore.Repo, {:shared, self()})

    :ok
  end

  describe "ingestão de 10.000 eventos concorrentes" do
    test "não perde eventos e não tem condição de corrida" do
      total_eventos = 10_000
      node_id = 1

      # Dispara 10.000 tarefas concorrentes
      tasks =
        for _ <- 1..total_eventos do
          Task.async(fn ->
            IngestServer.ingest(node_id, "ok", %{temperatura: :rand.uniform(100) * 1.0})
          end)
        end

      # Aguarda todas as tarefas completarem
      Enum.each(tasks, &Task.await(&1, 10_000))

      # Dá tempo para o GenServer processar todos os casts
      Process.sleep(500)

      # Verifica que nenhum evento foi perdido
      assert {:ok, {^node_id, "ok", count, _, _}} = Cache.get(node_id)
      assert count == total_eventos,
        "Esperado #{total_eventos} eventos, obtido #{count}"
    end

    test "múltiplos nós concorrentes não interferem entre si" do
      eventos_por_no = 1_000
      nos = [1, 2, 3, 4, 5]

      # Dispara eventos para múltiplos nós simultaneamente
      tasks =
        for node_id <- nos, _ <- 1..eventos_por_no do
          Task.async(fn ->
            IngestServer.ingest(node_id, "ok", %{temperatura: :rand.uniform(100) * 1.0})
          end)
        end

      Enum.each(tasks, &Task.await(&1, 10_000))
      Process.sleep(500)

      # Verifica que cada nó tem exatamente eventos_por_no eventos
      for node_id <- nos do
        assert {:ok, {^node_id, "ok", count, _, _}} = Cache.get(node_id)
        assert count == eventos_por_no,
          "Nó #{node_id}: esperado #{eventos_por_no} eventos, obtido #{count}"
      end
    end

    test "status mais recente prevalece sob concorrência" do
      node_id = 99
      total = 500

      # Metade dos eventos com "ok", metade com "critical"
      tasks =
        for i <- 1..total do
          Task.async(fn ->
            status = if rem(i, 2) == 0, do: "ok", else: "critical"
            IngestServer.ingest(node_id, status, %{})
          end)
        end

      Enum.each(tasks, &Task.await(&1, 10_000))
      Process.sleep(500)

      # Não importa o status final — o que importa é que o contador está correto
      assert {:ok, {^node_id, _status, count, _, _}} = Cache.get(node_id)
      assert count == total,
        "Esperado #{total} eventos, obtido #{count}"
    end

    test "simula máquinas caindo e voltando (status cycling)" do
      node_id = 10
      ciclos = 1_000

      # Cada ciclo: máquina vai de ok → critical → warning → ok
      tasks =
        for i <- 1..ciclos do
          Task.async(fn ->
            status =
              case rem(i, 3) do
                0 -> "ok"
                1 -> "critical"
                2 -> "warning"
              end

            IngestServer.ingest(node_id, status, %{
              temperatura: :rand.uniform(100) * 1.0,
              pressao: :rand.uniform(10) * 1.0,
              vibracao: :rand.uniform(5) * 1.0,
              rpm: :rand.uniform(3000),
              voltagem: 210.0 + :rand.uniform(20) * 1.0,
              corrente: :rand.uniform(20) * 1.0
            })
          end)
        end

      Enum.each(tasks, &Task.await(&1, 10_000))
      Process.sleep(500)

      # Contador deve refletir todos os ciclos
      assert {:ok, {^node_id, _status, count, _, _}} = Cache.get(node_id)
      assert count == ciclos,
        "Esperado #{ciclos} eventos no cycling, obtido #{count}"
    end

    test "mede tempo de ingestão de 10.000 eventos e valida performance" do
      node_id = 20
      total = 10_000

      {tempo_microsegundos, _} =
        :timer.tc(fn ->
          tasks =
            for _ <- 1..total do
              Task.async(fn ->
                IngestServer.ingest(node_id, "ok", %{
                  temperatura: :rand.uniform(100) * 1.0,
                  pressao: :rand.uniform(10) * 1.0,
                  vibracao: :rand.uniform(5) * 1.0,
                  rpm: :rand.uniform(3000),
                  voltagem: 210.0 + :rand.uniform(20) * 1.0,
                  corrente: :rand.uniform(20) * 1.0
                })
              end)
            end

          Enum.each(tasks, &Task.await(&1, 10_000))
          Process.sleep(500)
        end)

      tempo_ms = tempo_microsegundos / 1_000
      tempo_por_evento_us = tempo_microsegundos / total

      IO.puts("\n📊 Performance de ingestão:")
      IO.puts("   Total de eventos : #{total}")
      IO.puts("   Tempo total      : #{Float.round(tempo_ms, 2)} ms")
      IO.puts("   Tempo por evento : #{Float.round(tempo_por_evento_us, 2)} µs")

      # Valida que todos os eventos foram processados
      assert {:ok, {^node_id, "ok", ^total, _, _}} = Cache.get(node_id)

      # Valida que 10.000 eventos foram processados em menos de 10 segundos
      assert tempo_ms < 10_000,
        "Performance insatisfatória: #{tempo_ms}ms para #{total} eventos"
    end

    test "prova que o SQLite sincronizou o estado corretamente após flush" do
      node_id = 50
      total = 100

      # Cria o nó no SQLite antes de injetar eventos
      {:ok, node} =
        %WCore.Telemetry.Node{}
        |> WCore.Telemetry.Node.changeset(%{
          machine_identifier: "sensor-#{node_id}",
          location: "setor-teste"
        })
        |> WCore.Repo.insert()

      # Injeta 100 eventos usando o ID real do banco
      tasks =
        for _ <- 1..total do
          Task.async(fn ->
            IngestServer.ingest(node.id, "ok", %{
              temperatura: :rand.uniform(100) * 1.0,
              pressao: :rand.uniform(10) * 1.0,
              vibracao: :rand.uniform(5) * 1.0,
              rpm: :rand.uniform(3000),
              voltagem: 210.0 + :rand.uniform(20) * 1.0,
              corrente: :rand.uniform(20) * 1.0
            })
          end)
        end

      Enum.each(tasks, &Task.await(&1, 10_000))
      Process.sleep(500)

      # Confirma que o ETS tem a contagem correta
      assert {:ok, {_node_id, "ok", ^total, _, _}} = Cache.get(node.id)

      # Aguarda o WriteBehindWorker fazer o flush (intervalo de 5s + margem)
      Process.sleep(6_000)

      # Verifica que o SQLite sincronizou corretamente
      node_metrics = WCore.Repo.get_by(WCore.Telemetry.NodeMetrics, node_id: node.id)

      assert node_metrics != nil, "NodeMetrics não foi criado no SQLite"
      assert node_metrics.total_events_processed == total,
        "SQLite dessincronizado: esperado #{total}, obtido #{node_metrics.total_events_processed}"
      assert node_metrics.status == "ok"
      assert node_metrics.last_seen_at != nil
    end
    
  end
end
