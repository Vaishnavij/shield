defmodule Shield.Policy.User.Login do
  @moduledoc """
  User.Login policy
  """

  alias Authable.Utils.Crypt, as: CryptUtil
  alias Shield.Arm.OneTimePassword, as: OneTimePasswordArm

  @repo Application.get_env(:authable, :repo)
  @user Application.get_env(:authable, :resource_owner)
  @token_store Application.get_env(:authable, :token_store)

  @doc """
  Runs login process for given params
  - Validates email exists
  - Validates password authentication
  - Validates email confirmation if needed
  - Validates one time password if needed
  - Insert session token to DB
  """
  def process(params) do
    params
    |> validate_email_exists()
    |> validate_email_password_match()
    |> validate_email_confirmation()
    |> validate_one_time_password()
    |> insert_access_token()
  end

  defp validate_email_exists(%{"email" => email} = params) do
    case @repo.get_by(@user, email: email) do
      nil -> {:error, {:unauthorized, %{email: ["Email could not found."]}}}
      user -> {:ok, Map.put(params, "user", user)}
    end
  end

  defp validate_email_password_match({:ok, %{"user" => user, "password" => password} = params}) do
    case CryptUtil.match_password(password, Map.get(user, :password, "")) do
      false -> {:error, {:unauthorized, %{password: ["Wrong password!"]}}}
      true -> {:ok, params}
    end
  end
  defp validate_email_password_match({:error, {_status, _errors} = opts}),
    do: {:error, opts}

  defp validate_email_confirmation({:ok, %{"user" => user} = params}) do
    is_email_confirmation_required = Application.get_env(:shield, :confirmable)
    is_email_confirmed = Map.get(user.settings || %{}, "confirmed", false)

    case {is_email_confirmation_required, is_email_confirmed} do
      {false, _} -> {:ok, params}
      {true, true} -> {:ok, params}
      {_, _} -> {:error, {:unauthorized,
        %{email: ["Email confirmation required."]}}}
    end
  end
  defp validate_email_confirmation({:error, {_status, _errors} = opts}),
    do: {:error, opts}

  defp validate_one_time_password({:ok, %{"user" => user} = params}) do
    is_otp_check_required = Application.get_env(:shield, :otp_check)
    is_otp_check_enabled = Map.get(user.settings || %{}, "otp_enabled", false)

    case {is_otp_check_required, is_otp_check_enabled} do
      {nil, _} -> {:ok, params}
      {false, _} -> {:ok, params}
      {true, false} -> {:ok, params}
      {true, true} -> validate_one_time_password_value({:ok, params})
    end
  end
  defp validate_one_time_password({:error, {_status, _errors} = opts}),
    do: {:error, opts}

  defp validate_one_time_password_value({:ok, %{"user" => user} = params}) do
    case OneTimePasswordArm.find_otp_secret_token(user) do
      nil ->
        {:error, {:unauthorized, %{otp_secret_token: ["Not found"]}}}
      token ->
        otp_value = Map.get(params, "otp_value", "")
        case OneTimePasswordArm.is_valid?(token.value, otp_value) do
          false -> {:error, {:unauthorized,
            %{otp_value: ["Invalid one time password"]}}}
          true -> {:ok, params}
        end
    end
  end

  defp insert_access_token({:ok, %{"user" => user} = params}) do
    changeset = @token_store.access_token_changeset(%@token_store{},
      %{user_id: user.id, details: %{"scope" => "session"}})
    case @repo.insert(changeset) do
        {:ok, token} ->
          {:ok, Map.put(params, "token", token)}
        {:error, changeset} ->
          {:error, {:unprocessable_entity, changeset}}
    end
  end

  defp insert_session_token({:ok, %{"user" => user} = params}) do
    changeset = @token_store.session_token_changeset(%@token_store{},
      %{user_id: user.id, details: %{"scope" => "session"}})
    case @repo.insert(changeset) do
      {:ok, token} ->
        {:ok, Map.put(params, "token", token)}
      {:error, changeset} ->
        {:error, {:unprocessable_entity, changeset}}
    end
  end
  defp insert_session_token({:error, {_status, _errors} = opts}),
    do: {:error, opts}
end
