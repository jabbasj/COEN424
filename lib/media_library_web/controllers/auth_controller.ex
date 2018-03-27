defmodule MediaLibraryWeb.OAuthController do
  use MediaLibraryWeb, :controller

  alias MediaLibraryWeb.SessionController
  alias MediaLibraryWeb.UserController
  alias MediaLibrary.OAuth

  
  @doc """
  Redirects user to OAuth login form of chosen provider.
  """
  def new(conn, %{"provider" => provider}) do
    redirect conn, external: MediaLibrary.OAuth.authorize_url!(provider)
  end

  @doc """
  OAuth callback.
  
  Gets relevant authentication data and invokes proper action for
  further processing.
  """
  def callback(conn, %{"provider" => provider, "code" => code, "state" => state} = params) do
    token = OAuth.get_token!(provider, code)   
    user_params = OAuth.get_user_params!(provider, token)
    params = Map.put(params, "user_params", user_params) |> Map.put("token", token.token)

    case state do
      "login" ->
        SessionController.create_oauth(conn, params)
      "drive" ->
        UserController.associate_drive(conn, params)
    end
  end

end
