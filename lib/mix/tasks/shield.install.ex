defmodule Mix.Tasks.Shield.Install do
  use Mix.Task

  @version Mix.Project.config[:version]
  @shortdoc "Creates default views and controllers inside current application."

  # File mappings

  @controllers [
    {:eex,  "web/controllers/app_controller.ex", "web/controllers/shield/app_controller.ex"},
    {:eex,  "web/controllers/client_controller.ex", "web/controllers/shield/client_controller.ex"},
    {:eex,  "web/controllers/token_controller.ex", "web/controllers/shield/token_controller.ex"},
    {:eex,  "web/controllers/user_controller.ex", "web/controllers/shield/user_controller.ex"},
  ]

  @views [
    {:eex,  "web/views/app_view.ex", "web/views/shield/app_view.ex"},
    {:eex,  "web/views/changeset_view.ex", "web/views/shield/changeset_view.ex"},
    {:eex,  "web/views/client_view.ex", "web/views/shield/client_view.ex"},
    {:eex,  "web/views/error_view.ex", "web/views/shield/error_view.ex"},
    {:eex,  "web/views/token_view.ex", "web/views/shield/token_view.ex"},
    {:eex,  "web/views/user_view.ex", "web/views/shield/user_view.ex"},
  ]

  @models [
    {:eex,  "web/models/app.ex", "web/models/authable/app.ex"},
    {:eex,  "web/models/client.ex", "web/models/authable/client.ex"},
    {:eex,  "web/models/token.ex", "web/models/authable/token.ex"},
    {:eex,  "web/models/user.ex", "web/models/authable/user.ex"},
  ]

  @migrations [
    {:eex,  "priv/repo/migrations/20160503214613_create_user.exs", "priv/repo/migrations/20160503214613_create_user.exs"},
    {:eex,  "priv/repo/migrations/20160504001808_create_token.exs", "priv/repo/migrations/20160504001808_create_token.exs"},
    {:eex,  "priv/repo/migrations/20160504001852_create_client.exs", "priv/repo/migrations/20160504001852_create_client.exs"},
    {:eex,  "priv/repo/migrations/20160504007852_create_app.exs", "priv/repo/migrations/20160504007852_create_app.exs"},
  ]

  @moduledoc """
  Installs shield controllers and views.

  ## Examples

      mix shield.install
  """
  def run([version]) when version in ~w(-v --version) do
    Mix.shell.info "Shield v#{@version}"
  end

  def run(_argv) do
    unless Version.match? System.version, "~> 1.2" do
      Mix.raise "Shield v#{@version} requires at least Elixir v1.2.\n " <>
                "You have #{System.version}. Please update accordingly"
    end

    multi_cp()
  end

  defp multi_cp do
    Mix.Phoenix.copy_from shield_paths(), "./deps/shield/", [], @controllers
    Mix.Phoenix.copy_from shield_paths(), "./deps/shield/", [], @views
    Mix.Phoenix.copy_from authable_paths(), "./deps/authable/", [], @models
    Mix.Phoenix.copy_from authable_paths(), "./deps/authable/", [], @migrations

    print_controllers_info()
    print_ecto_info()
  end

  defp shield_paths do
    [".", :shield]
  end

  defp authable_paths do
    [".", :authable]
  end

  defp print_controllers_info do
    Mix.shell.info """
    Add following routes to web/router.ex file:

        pipeline :api do
          plug :accepts, ["json"]
        end

        scope "/", Shield do
          pipe_through :api
          resources "/clients", ClientController, except: [:new, :edit]

          get     "/apps", AppController, :index
          get     "/apps/:id", AppController, :show
          delete  "/apps/:id", AppController, :delete
          post    "/apps/authorize", AppController, :authorize

          get     "/tokens/:id", TokenController, :show
          post    "/tokens", TokenController, :create

          post    "/users/register", UserController, :register
          post    "/users/login", UserController, :login
          delete  "/users/logout", UserController, :logout
          get     "/users/me", UserController, :me
          get     "/users/confirm", UserController, :confirm
          post    "/users/recover_password", UserController, :recover_password
          post    "/users/reset_password", UserController, :reset_password
          post    "/users/change_password", UserController, :change_password

          get     "/settings", SettingController, :index
          put     "/settings/:id", SettingController, :update
          patch   "/settings/:id", SettingController, :update
        end
    """
    nil
  end

  defp print_ecto_info do
    Mix.shell.info """
    Before moving on, configure your database in config/dev.exs and run:

        $ mix ecto.create
        $ mix ecto.migrate -r Authable.Repo
    """
    nil
  end
end
