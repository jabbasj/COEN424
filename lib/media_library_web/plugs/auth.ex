defmodule MediaLibraryWeb.Auth do
  @moduledoc """
  Authentication plug implementation.

  Contains functionality for login, logout and authorization
  """

  import Plug.Conn
  import Phoenix.Controller
  import Comeonin.Pbkdf2, only: [checkpw: 2, dummy_checkpw: 0]

  alias MediaLibraryWeb.Router.Helpers
  alias MediaLibrary.Accounts

  @doc """
  Plug initialization.
  """
  def init(opts) do
    opts
  end

  @doc """
  Plug function.

  If user is logged in, stores their ID in conn.assigns
  under current_user.
  """
  def call(conn, _opts) do
    user_id = get_session(conn, :user_id)
    user = user_id && Accounts.get_user(user_id)
    assign(conn, :current_user, user)
  end

  @doc """
  Makes sure that user is authenticated.
  """
  def authenticate(conn, _opts) do
    if conn.assigns.current_user do
      conn
    else
      conn
      |> put_flash(:error, "You must be logged in to access that page")
      |> redirect(to: Helpers.page_path(conn, :index))
      |> halt()
    end
  end

  @doc """
  Adds user information to session.
  """
  def login(conn, user) do
    conn
    |> assign(:current_user, user)
    |> put_session(:user_id, user.id)
    |> configure_session(renew: true)
  end

  @doc """
  Drops current session.
  """
  def logout(conn) do
    configure_session(conn, drop: true)
  end

  @doc """
  Logs in user by e-mail.

  Used with OAuth authentication.
  """
  def login_by_email(conn, email) do
    case  Accounts.get_user_by(email: email) do
      nil ->
        {:error, :not_found, conn}
      user ->
        {:ok, login(conn, user)}
    end
  end

  @doc """
  Validates login username and password against the
  database for local login
  """
  def validate_login_data(conn, email, given_pass) do
    user = Accounts.get_user_by(email: email)  
    cond do
      user && user.password_hash == nil ->
        {:error, :non_local, conn}
      user && checkpw(given_pass, user.password_hash) ->
        {:ok, login(conn, user)}
      user ->
        {:error, :unauthorized, conn}
      true ->
        dummy_checkpw()
        {:error, :not_found, conn}
    end
  end
end
