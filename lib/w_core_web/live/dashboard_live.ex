defmodule WCoreWeb.DashboardLive do
  use WCoreWeb, :live_view

  alias WCore.Telemetry.Cache

  @moduledoc """
  Sala de Controle da Planta 42.

  Lê o estado atual dos sensores direto do ETS (camada quente)
  e reage em tempo real via PubSub quando novos pulsos chegam.
  """

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      # Subscreve no tópico geral de telemetria
      Phoenix.PubSub.subscribe(WCore.PubSub, "telemetry:updates")
    end

    nodes = load_nodes()

    {:ok, assign(socket, nodes: nodes, total: length(nodes))}
  end

  @impl true
  def handle_info({:node_update, _node_id, _status}, socket) do
    # Recarrega apenas quando recebe notificação de mudança
    nodes = load_nodes()
    {:noreply, assign(socket, nodes: nodes, total: length(nodes))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-950 text-white p-6">
      <div class="max-w-7xl mx-auto">

        <%!-- Cabeçalho --%>
        <div class="flex items-center justify-between mb-8">
          <div>
            <h1 class="text-2xl font-bold text-white">Sala de Controle</h1>
            <p class="text-gray-400 text-sm mt-1">Planta 42 — Monitoramento em tempo real</p>
          </div>
          <div class="flex items-center gap-2">
            <span class="w-2 h-2 rounded-full bg-green-400 animate-pulse"></span>
            <span class="text-sm text-gray-400">Sistema operacional</span>
          </div>
        </div>

        <%!-- Resumo geral --%>
        <div class="grid grid-cols-3 gap-4 mb-8">
          <.stat_card label="Total de Sensores" value={@total} />
          <.stat_card label="Ativos" value={count_by_status(@nodes, "ok")} color="green" />
          <.stat_card label="Em Alerta" value={count_by_status(@nodes, "critical")} color="red" />
        </div>

        <%!-- Grid de sensores --%>
        <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
          <.node_card :for={node <- @nodes} node={node} />
        </div>

        <%!-- Estado vazio --%>
        <%= if @total == 0 do %>
          <div class="text-center py-24 text-gray-500">
            <p class="text-lg">Nenhum sensor detectado.</p>
            <p class="text-sm mt-1">Aguardando pulsos dos dispositivos...</p>
          </div>
        <% end %>

      </div>
    </div>
    """
  end

  # --- Componentes HEEx ---

  attr :label, :string, required: true
  attr :value, :integer, required: true
  attr :color, :string, default: "white"

  defp stat_card(assigns) do
    ~H"""
    <div class="bg-gray-900 border border-gray-800 rounded-xl p-5">
      <p class="text-sm text-gray-400"><%= @label %></p>
      <p class={"text-3xl font-bold mt-1 text-#{@color}-400"}><%= @value %></p>
    </div>
    """
  end

  attr :node, :any, required: true
  defp node_card(assigns) do
    ~H"""
    <div class={"bg-gray-900 border rounded-xl p-5 transition-all duration-300 #{border_color(@node)} #{alert_animation(@node)}"}>
      <%!-- Cabeçalho do card --%>
      <div class="flex items-center justify-between mb-4">
        <div>
          <p class="font-mono font-bold text-white">Sensor <%= elem(@node, 0) %></p>
          <p class="text-xs text-gray-500 mt-0.5">ID: <%= elem(@node, 0) %></p>
        </div>
        <.status_badge status={elem(@node, 1)} />
      </div>

      <%!-- Alerta crítico --%>
      <%= if elem(@node, 1) == "critical" do %>
        <div class="flex items-center gap-2 bg-red-950 border border-red-800 rounded-lg px-3 py-2 mb-4 animate-pulse">
          <span class="w-2 h-2 rounded-full bg-red-400 animate-ping"></span>
          <span class="text-red-300 text-xs font-semibold">ALERTA CRÍTICO — Intervenção necessária</span>
        </div>
      <% end %>

      <%!-- Métricas principais --%>
      <div class="grid grid-cols-2 gap-3 mb-4">
        <.metrica
          label="Temperatura"
          valor={payload_campo(@node, :temperatura)}
          unidade="°C"
          alerta={elem(@node, 1) == "critical"}
        />
        <.metrica
          label="Pressão"
          valor={payload_campo(@node, :pressao)}
          unidade="bar"
          alerta={false}
        />
        <.metrica
          label="Vibração"
          valor={payload_campo(@node, :vibracao)}
          unidade="mm/s"
          alerta={false}
        />
        <.metrica
          label="RPM"
          valor={payload_campo(@node, :rpm)}
          unidade="rpm"
          alerta={false}
        />
        <.metrica
          label="Voltagem"
          valor={payload_campo(@node, :voltagem)}
          unidade="V"
          alerta={false}
        />
        <.metrica
          label="Corrente"
          valor={payload_campo(@node, :corrente)}
          unidade="A"
          alerta={false}
        />
      </div>

      <%!-- Rodapé do card --%>
      <div class="border-t border-gray-800 pt-3 flex items-center justify-between text-xs text-gray-500">
        <span>Eventos: <span class="text-gray-300 font-mono"><%= elem(@node, 2) %></span></span>
        <span>Último pulso: <span class="text-gray-300"><%= format_ts(elem(@node, 4)) %></span></span>
      </div>
    </div>
    """
  end

  defp alert_animation(node) do
    case elem(node, 1) do
      "critical" -> "ring-2 ring-red-500 ring-offset-2 ring-offset-gray-950"
      _ -> ""
    end
  end

  attr :label, :string, required: true
  attr :valor, :any, required: true
  attr :unidade, :string, required: true
  attr :alerta, :boolean, default: false

  defp metrica(assigns) do
    ~H"""
    <div class={"rounded-lg p-3 #{if @alerta, do: "bg-red-950 border border-red-800", else: "bg-gray-800"}"}>
      <p class="text-xs text-gray-400 mb-1"><%= @label %></p>
      <p class={"font-mono font-bold text-lg #{if @alerta, do: "text-red-300", else: "text-white"}"}>
        <%= @valor %> <span class="text-xs font-normal text-gray-500"><%= @unidade %></span>
      </p>
    </div>
    """
  end

  defp payload_campo(node, campo) do
    case elem(node, 3) do
      %{} = payload -> Map.get(payload, campo, "—")
      _ -> "—"
    end
  end


  attr :status, :string, required: true

  defp status_badge(assigns) do
    ~H"""
    <span class={"text-xs font-semibold px-2 py-1 rounded-full #{badge_color(@status)}"}>
      <%= translate_status(@status) %>
    </span>
    """
  end

  # --- Funções auxiliares ---

  defp load_nodes do
    Cache.all()
    |> Enum.sort_by(&elem(&1, 0))
  end

  defp count_by_status(nodes, status) do
    Enum.count(nodes, fn node -> elem(node, 1) == status end)
  end

  defp border_color(node) do
    case elem(node, 1) do
      "ok"       -> "border-green-800"
      "critical" -> "border-red-800 shadow-red-900 shadow-md"
      "warning"  -> "border-yellow-800"
      _          -> "border-gray-800"
    end
  end

  defp badge_color(status) do
    case status do
      "ok"       -> "bg-green-900 text-green-300"
      "critical" -> "bg-red-900 text-red-300"
      "warning"  -> "bg-yellow-900 text-yellow-300"
      _          -> "bg-gray-800 text-gray-400"
    end
  end

  defp translate_status(status) do
    case status do
      "ok"       -> "Operacional"
      "critical" -> "Crítico"
      "warning"  -> "Atenção"
      _          -> "Desconhecido"
    end
  end

  defp format_ts(ts) do
    ts
    |> DateTime.truncate(:second)
    |> DateTime.to_string()
  end
end
