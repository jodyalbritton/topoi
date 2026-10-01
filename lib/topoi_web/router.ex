defmodule TopoiWeb.Router do
  use TopoiWeb, :router

  import TopoiWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {TopoiWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  # Public library. Signed-in users are recognised (header, and later the
  # "helpful" ratings) but nothing here requires an account.
  scope "/", TopoiWeb do
    pipe_through :browser

    live_session :public, on_mount: [{TopoiWeb.UserAuth, :mount_current_scope}] do
      live "/", HomeLive, :index
      live "/search", SearchLive, :index
      live "/about", AboutLive, :index
      live "/debaters", LibraryLive, :debaters
      live "/debates", LibraryLive, :debates
      live "/topics", LibraryLive, :topics
      live "/tags", LibraryLive, :tags
      live "/schools", LibraryLive, :schools
    end

    # JobyKit inventory pages (component previews for people and agents).
    live "/design", DesignSystemLive, :index
    live "/custom-designs", CustomDesignsLive, :index
  end

  # Admin workspace: ingest, review gates, integration settings.
  scope "/admin", TopoiWeb.Admin do
    pipe_through [:browser, :require_authenticated_user, :require_admin_user]

    live_session :admin,
      on_mount: [
        {TopoiWeb.UserAuth, :require_authenticated},
        {TopoiWeb.UserAuth, :require_admin}
      ] do
      live "/", OverviewLive, :index
      live "/debates", DebatesLive, :index
      live "/debates/:id", DebateLive, :show
      live "/debaters", DebatersLive, :index
      live "/gateway", GatewayLive, :index
      live "/settings", SettingsLive, :index
    end
  end

  scope "/" do
    pipe_through :api

    get "/design.json", JobyKit.ManifestController, :show,
      private: %{joby_kit_manifest: TopoiWeb.DesignManifest}
  end

  if Application.compile_env(:topoi, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: TopoiWeb.Telemetry

      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/", TopoiWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [{TopoiWeb.UserAuth, :require_authenticated}] do
      live "/users/settings", UserLive.Settings, :edit
      live "/users/settings/confirm-email/:token", UserLive.Settings, :confirm_email
    end

    post "/users/update-password", UserSessionController, :update_password
  end

  scope "/", TopoiWeb do
    pipe_through [:browser]

    live_session :current_user,
      on_mount: [{TopoiWeb.UserAuth, :mount_current_scope}] do
      # No public registration and no magic-link login: accounts come from
      # seeds or an admin, and log in with username + password.
      live "/users/log-in", UserLive.Login, :new
    end

    post "/users/log-in", UserSessionController, :create
    delete "/users/log-out", UserSessionController, :delete
  end
end
