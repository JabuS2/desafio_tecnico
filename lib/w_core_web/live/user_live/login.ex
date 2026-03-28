defmodule WCoreWeb.UserLive.Login do
  use WCoreWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-sm">
        <div class="text-center">
          <.header>
            Entrar na Planta 42
            <:subtitle>
              <%= if @current_scope do %>
                Reautentique-se para continuar.
              <% else %>
                Não tem conta?
                <.link navigate={~p"/users/register"} class="font-semibold text-brand hover:underline">
                  Criar conta
                </.link>
              <% end %>
            </:subtitle>
          </.header>
        </div>

        <.form
          :let={f}
          for={@form}
          id="login_form"
          action={~p"/users/log-in"}
          phx-submit="submit"
          phx-trigger-action={@trigger_submit}
        >
          <.input
            readonly={!!@current_scope}
            field={f[:email]}
            type="email"
            label="E-mail"
            autocomplete="username"
            spellcheck="false"
            required
            phx-mounted={JS.focus()}
          />
          <.input
            field={f[:password]}
            type="password"
            label="Senha"
            autocomplete="current-password"
            spellcheck="false"
            required
          />
          <.input
            field={f[:remember_me]}
            type="checkbox"
            label="Manter conectado"
          />
          <.button phx-disable-with="Entrando..." class="btn btn-primary w-full mt-4">
            Entrar
          </.button>
        </.form>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    email =
      Phoenix.Flash.get(socket.assigns.flash, :email) ||
        get_in(socket.assigns, [:current_scope, Access.key(:user), Access.key(:email)])

    form = to_form(%{"email" => email, "remember_me" => "true"}, as: "user")

    {:ok, assign(socket, form: form, trigger_submit: false)}
  end

  @impl true
  def handle_event("submit", _params, socket) do
    {:noreply, assign(socket, :trigger_submit, true)}
  end
end
