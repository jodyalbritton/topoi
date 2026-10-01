defmodule TopoiWeb.UserSessionController do
  use TopoiWeb, :controller

  alias Topoi.Accounts
  alias TopoiWeb.UserAuth

  def create(conn, params) do
    create(conn, params, "Welcome back!")
  end

  # username + password login (the only login path)
  defp create(
         conn,
         %{"user" => %{"username" => username, "password" => password} = user_params},
         info
       )
       when is_binary(username) and is_binary(password) do
    if user = Accounts.get_user_by_username_and_password(username, password) do
      conn
      |> put_flash(:info, info)
      |> UserAuth.log_in_user(user, user_params)
    else
      # In order to prevent user enumeration attacks, don't disclose whether the username exists.
      conn
      |> put_flash(:error, "Invalid username or password")
      |> put_flash(:username, String.slice(username, 0, 32))
      |> redirect(to: ~p"/users/log-in")
    end
  end

  # anything else (e.g. a magic-link token post): not a supported login path
  defp create(conn, _params, _info) do
    conn
    |> put_flash(:error, "Invalid username or password")
    |> redirect(to: ~p"/users/log-in")
  end

  def update_password(conn, %{"user" => user_params} = params) do
    user = conn.assigns.current_scope.user
    true = Accounts.sudo_mode?(user)
    {:ok, {_user, expired_tokens}} = Accounts.update_user_password(user, user_params)

    # disconnect all existing LiveViews with old sessions
    UserAuth.disconnect_sessions(expired_tokens)

    conn
    |> put_session(:user_return_to, ~p"/users/settings")
    |> create(params, "Password updated successfully!")
  end

  def delete(conn, _params) do
    conn
    |> put_flash(:info, "Logged out successfully.")
    |> UserAuth.log_out_user()
  end
end
