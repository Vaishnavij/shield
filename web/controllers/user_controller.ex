defmodule Shield.UserController do
  use Shield.Web, :controller
  alias Shield.Policy.User.ChangePassword, as: ChangePasswordPolicy
  alias Shield.Policy.User.Confirm, as: ConfirmPolicy
  alias Shield.Policy.User.Login, as: LoginPolicy
  alias Shield.Policy.User.Logout, as: LogoutPolicy
  alias Shield.Policy.User.RecoverPassword, as: RecoverPasswordPolicy
  alias Shield.Policy.User.Register, as: RegisterPolicy
  alias Shield.Policy.User.ResetPassword, as: ResetPasswordPolicy

  @renderer Application.get_env(:authable, :renderer)
  @views Application.get_env(:shield, :views)
  @hooks Application.get_env(:shield, :hooks)

  plug :scrub_params, "user" when action in [:register, :login]
  plug Authable.Plug.Authenticate, [scopes: ~w(read)] when action in [:me]
  plug Authable.Plug.Authenticate, [scopes: ~w(read write)] when action in [:logout]
  plug Authable.Plug.Authenticate, [scopes: ~w(session read write)] when action in [:change_password]
  plug Authable.Plug.UnauthorizedOnly when action in [:register, :login, :confirm, :recover_password, :reset_password]
  plug Shield.Arm.Confirmable, [enabled: Application.get_env(:shield, :confirmable)] when action in [:me, :change_password]

  # GET /users/me
  def me(conn, _) do
    conn
    |> put_status(:ok)
    |> render(@views[:user], "show.json", user: conn.assigns[:current_user])
  end

  # GET /users/confirm
  def confirm(conn, %{"confirmation_token" => _} = user_params) do
    case ConfirmPolicy.process(user_params) do
      {:ok, res} ->
        conn
        |> @hooks.after_user_confirm_success({user_params, res})
        |> @renderer.render(:ok, res)
      {:error, {http_status_code, %Ecto.Changeset{} = errors} = res} ->
        conn
        |> @hooks.after_user_confirm_failure({user_params, res})
        |> put_status(http_status_code)
        |> render(@views[:changeset], "error.json", changeset: errors)
      {:error, {http_status_code, errors} = res} ->
        conn
        |> @hooks.after_user_confirm_failure({user_params, res})
        |> @renderer.render(http_status_code, %{errors: errors})
    end
  end
  def confirm(conn, _) do
    @renderer.render(conn, :unprocessable_entity, %{errors:
      %{details: "Missing confirmation_token data!"}})
  end

  # POST /users/recover-password
  def recover_password(conn, %{"user" => %{"email" => _} = user_params}) do
    case RecoverPasswordPolicy.process(user_params) do
      {:ok, %{"user" => user, "token" => token} = res} ->
        conn
        |> @hooks.after_user_recover_password_success({user_params, res})
        |> assign(:current_user, user)
        |> fetch_session
        |> put_session(:session_token, token.value)
        |> configure_session(renew: true)
        |> put_status(:created)
        |> render(@views[:user], "show.json", user: user)
      {:error, {http_status_code, %Ecto.Changeset{} = errors} = res} ->
        conn
        |> @hooks.after_user_recover_password_failure({user_params, res})
        |> put_status(http_status_code)
        |> render(@views[:changeset], "error.json", changeset: errors)
      {:error, {http_status_code, errors} = res} ->
        conn
        |> @hooks.after_user_recover_password_failure({user_params, res})
        |> @renderer.render(http_status_code, %{errors: errors})
    end
  end
  def recover_password(conn, _) do
    @renderer.render(conn, :unprocessable_entity, %{errors:
      %{details: "Missing email data!"}})
  end

  # POST /users/register
  def register(conn, %{"user" => %{"email" => _, "password" => _} = user_params} = params) do
    conn = @hooks.before_user_register(conn, params)
    case RegisterPolicy.process(user_params) do
      {:ok, %{"user" => user} = res} ->
        conn
        |> @hooks.after_user_register_success({user_params, res})
        |> put_status(:created)
        |> render(@views[:user], "show.json", user: user)
      {:error, {http_status_code, %Ecto.Changeset{} = errors} = res} ->
        conn
        |> @hooks.after_user_login_failure({user_params, res})
        |> put_status(http_status_code)
        |> render(@views[:changeset], "error.json", changeset: errors)
      {:error, {http_status_code, errors} = res} ->
        conn
        |> @hooks.after_user_register_failure({user_params, res})
        |> @renderer.render(http_status_code, %{errors: errors})
    end
  end
  def register(conn, _) do
    @renderer.render(conn, :unprocessable_entity, %{errors:
      %{details: "Missing email or password data!"}})
  end

  # POST /users/login
  def login(conn, %{"user" => %{"email" => email, "password" => password} = user_params} = params) when is_binary(password) and is_binary(email) do
    conn = @hooks.before_user_login(conn, params)
    case LoginPolicy.process(user_params) do
      {:ok, %{"user" => user, "token" => token} = res} ->
        conn
        |> @hooks.after_user_login_success({user_params, res})
        |> assign(:current_user, user)
        |> fetch_session
        |> put_session(:acces_token, token.value)
        |> configure_session(renew: true)
        |> put_status(:created)
        |> render(@views[:token], "token.json", token: token)
      {:error, {http_status_code, %Ecto.Changeset{} = errors} = res} ->
        conn
        |> @hooks.after_user_login_failure({user_params, res})
        |> put_status(http_status_code)
        |> render(@views[:changeset], "error.json", changeset: errors)
      {:error, {http_status_code, errors} = res} ->
        conn
        |> @hooks.after_user_login_failure({user_params, res})
        |> @renderer.render(http_status_code, %{errors: errors})
    end
  end
  def login(conn, _) do
    @renderer.render(conn, :unprocessable_entity, %{errors:
      %{details: "Missing email or password data!"}})
  end

  # DELETE /users/logout
  def logout(conn, _) do
    token_value = get_session(fetch_session(conn), :session_token)
    LogoutPolicy.process(%{"token_value" => token_value})

    conn
    |> fetch_session()
    |> configure_session(drop: true)
    |> send_resp(:no_content, "")
  end

  # POST /users/reset-password
  def reset_password(conn, %{"user" => %{"password" => _, "reset_token" => _} = user_params}) do
    case ResetPasswordPolicy.process(user_params) do
      {:ok, res} ->
        conn
        |> @hooks.after_user_reset_password_success({user_params, res})
        |> @renderer.render(:ok, %{messages: "Password updated!"})
      {:error, {http_status_code, %Ecto.Changeset{} = errors} = res} ->
        conn
        |> @hooks.after_user_reset_password_failure({user_params, res})
        |> put_status(http_status_code)
        |> render(@views[:changeset], "error.json", changeset: errors)
      {:error, {http_status_code, errors} = res} ->
        conn
        |> @hooks.after_user_reset_password_failure({user_params, res})
        |> @renderer.render(http_status_code, %{errors: errors})
    end
  end
  def reset_password(conn, _) do
    @renderer.render(conn, :unprocessable_entity, %{errors:
      %{details: "Missing password or reset_token data!"}})
  end

  # POST /users/change-password
  def change_password(conn, %{"user" => %{"password" => _, "old_password" => _} = user_params}) do
    params_with_user = Map.put(user_params, "user", conn.assigns[:current_user])
    case ChangePasswordPolicy.process(params_with_user) do
      {:ok, res} ->
        conn
        |> @hooks.after_user_change_password_success({user_params, res})
        |> @renderer.render(:ok, %{messages: "Password updated!"})
      {:error, {http_status_code, %Ecto.Changeset{} = errors} = res} ->
        conn
        |> @hooks.after_user_change_password_failure({user_params, res})
        |> put_status(http_status_code)
        |> render(@views[:changeset], "error.json", changeset: errors)
      {:error, {http_status_code, errors} = res} ->
        conn
        |> @hooks.after_user_change_password_failure({user_params, res})
        |> @renderer.render(http_status_code, %{errors: errors})
    end
  end
  def change_password(conn, _) do
    @renderer.render(conn, :unprocessable_entity, %{errors:
      %{details: "Missing password or old_password data!"}})
  end
end
