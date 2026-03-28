defmodule WCore.Telemetry.CacheTest do
  use ExUnit.Case, async: false

  alias WCore.Telemetry.Cache

  @moduledoc """
  Testes unitários da camada ETS de telemetria.
  """

  setup do
    # Garante tabela limpa a cada teste
    try do
      :ets.delete(:w_core_telemetry_cache)
    rescue
      _ -> :ok
    end

    Cache.init()
    :ok
  end

  describe "upsert/3" do
    test "insere um novo nó corretamente" do
      Cache.upsert(1, "ok", %{temperatura: 72.5})

      assert {:ok, {1, "ok", 1, %{temperatura: 72.5}, _ts}} = Cache.get(1)
    end

    test "incrementa o contador de eventos a cada upsert" do
      Cache.upsert(1, "ok", %{temperatura: 72.5})
      Cache.upsert(1, "ok", %{temperatura: 73.0})
      Cache.upsert(1, "ok", %{temperatura: 74.0})

      assert {:ok, {1, "ok", 3, _, _}} = Cache.get(1)
    end

    test "atualiza o status corretamente" do
      Cache.upsert(1, "ok", %{temperatura: 72.5})
      Cache.upsert(1, "critical", %{temperatura: 98.0})

      assert {:ok, {1, "critical", 2, _, _}} = Cache.get(1)
    end

    test "atualiza o payload corretamente" do
      Cache.upsert(1, "ok", %{temperatura: 72.5})
      Cache.upsert(1, "ok", %{temperatura: 99.9})

      assert {:ok, {1, "ok", 2, %{temperatura: 99.9}, _}} = Cache.get(1)
    end
  end

  describe "get/1" do
    test "retorna erro para nó inexistente" do
      assert {:error, :not_found} = Cache.get(999)
    end

    test "retorna o registro correto para nó existente" do
      Cache.upsert(42, "warning", %{pressao: 2.5})

      assert {:ok, {42, "warning", 1, %{pressao: 2.5}, _}} = Cache.get(42)
    end
  end

  describe "all/0" do
    test "retorna lista vazia quando cache está vazio" do
      assert [] = Cache.all()
    end

    test "retorna todos os nós cadastrados" do
      Cache.upsert(1, "ok", %{})
      Cache.upsert(2, "critical", %{})
      Cache.upsert(3, "warning", %{})

      assert length(Cache.all()) == 3
    end
  end
end
