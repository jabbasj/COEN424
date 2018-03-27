defmodule MediaLibraryWeb.SessionController do
  @moduledoc """
  Controller responsible for login form and logging
  users in and out.
  """ 
  use MediaLibraryWeb, :controller

  alias MediaLibraryWeb.Auth
  alias MediaLibrary.Accounts

  @doc """
  Render login form.
  """
  def new(conn, _) do
    render conn, "new.html"
  end

  @doc """
  Log in user using local account.
  """
  def create(conn, %{"session" => %{"email" => email, "password" =>pass}}) do
    case Auth.validate_login_data(conn, email, pass) do
      {:ok, conn} ->
        conn
        |> put_flash(:info, "Welcome back!")
        |> redirect(to: video_path(conn, :index))
      {:error, :non_local, conn} ->
        conn
        |> put_flash(:error, "This account was created using an external login provider. Please sign in through the corresponding provider.")
        |> render("new.html")
      {:error, _reason, conn} ->
        conn
        |> put_flash(:error, "Invalid username/password combination")
        |> render("new.html")
    end
  end

  @doc """
  Log in user using OAuth data.

  If local account exists, updates access key.
  If local account does not exist, creates a new account.
  """
  def create_oauth(conn, %{"provider" => provider, "user_params" => user_params, "token" => token}) do
    user_email = user_params["email"]

    case Auth.login_by_email(conn, user_email) do
      {:ok, conn} ->
        Accounts.get_user_by(email: user_email)
        |> Accounts.update_access_key(provider, Map.from_struct(token))

        conn
        |> put_flash(:info, "Welcome back!")
        |> redirect(to: video_path(conn, :index))
      {:error, _reason, conn} ->
        user_params = Map.put(user_params, "access_keys", %{provider => Map.from_struct(token)})
        MediaLibraryWeb.UserController.create(conn, %{"user" => user_params})
    end 
  end
  
  @doc """
  Logout user.
  """
  def delete(conn, _) do
    conn
    |> Auth.logout()
    |> redirect(to: page_path(conn, :index))
  end
end 
