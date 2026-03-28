defmodule WCoreWeb.Router do
  use WCoreWeb, :router

  import WCoreWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {WCoreWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", WCoreWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  if Application.compile_env(:w_core, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: WCoreWeb.Telemetry
    end
  end

  ## Rotas autenticadas

  scope "/", WCoreWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [{WCoreWeb.UserAuth, :require_authenticated}] do
      live "/users/settings", UserLive.Settings, :edit
      live "/users/settings/confirm-email/:token", UserLive.Settings, :confirm_email
      # Sala de Controle da Planta 42
      live "/dashboard", DashboardLive, :index
    end

    post "/users/update-password", UserSessionController, :update_password
  end

  ## Rotas públicas

  scope "/", WCoreWeb do
    pipe_through [:browser]

    live_session :current_user,
      on_mount: [{WCoreWeb.UserAuth, :mount_current_scope}] do
      live "/users/register", UserLive.Registration, :new
      live "/users/log-in", UserLive.Login, :new
      live "/users/log-in/:token", UserLive.Confirmation, :new
    end

    post "/users/log-in", UserSessionController, :create
    delete "/users/log-out", UserSessionController, :delete
  end
end
