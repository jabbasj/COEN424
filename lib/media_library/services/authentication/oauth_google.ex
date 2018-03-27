defmodule MediaLibrary.OAuth.Google do
  @moduledoc """
  An OAuth2 strategy for Google.
  """
  use OAuth2.Strategy

  alias OAuth2.Strategy.AuthCode

  @doc """
  Creates a new Google OAuth client. 
  """
  def client do
   OAuth2.Client.new(
    [strategy: MediaLibrary.OAuth.Google,
     site: "https://accounts.google.com",
     client_id: "882417955578-eja8kbbkp4qj3e7i6t9kl7898gbbl487.apps.googleusercontent.com",
     client_secret: "7KyOUauvtZJW_kaUX7RDiZQx",
     redirect_uri: MediaLibraryWeb.Endpoint.url <> "/login/google/callback",
     authorize_url: "/o/oauth2/v2/auth",
     token_url: "https://www.googleapis.com/oauth2/v4/token"
     ])
  end

  @doc """
  Returns Google authorization site url.
  """
  def authorize_url!(params \\ []) do
    OAuth2.Client.authorize_url!(client(), params)
  end

  @doc """
  Returns Google login access token.
  """
  def get_token!(params \\ []) do
    OAuth2.Client.get_token!(client(), Keyword.merge(params, client_secret: client().client_secret))
  end

  @doc """
  Returns Google profile data of user using the access token.
  """
  def get_user_params(token) do
    response = OAuth2.Client.get!(token, "https://www.googleapis.com/plus/v1/people/me/openIdConnect", [], [timeout: 50_000, recv_timeout: 50_000])
    user = response.body

    %{"email" => user["email"], "name" => user["name"]}
  end

  @doc """
  Gets Google Drive file information.

  Currently only gets video files.
  """
  def get_drive_files(token) do
    token = keys_to_atoms(token)
    token = struct(OAuth2.AccessToken, token)

    client = Map.put(client(), :token, token)
    OAuth2.Client.get!(client, "https://www.googleapis.com/drive/v2/files?q=mimeType='video/mp4'")
  end

  @doc """
  Builds direct link to a file on Drive.
  """
  def get_file_url(file, token) do
    "https://www.googleapis.com/drive/v2/files/" <> file.path <> "?alt=media&key=AIzaSyDKhmVIasmQg8KgEfhAxI2is5kntKpCR5w&access_token=" <> token["access_token"]
  end

  @doc """
  Requests a thumbnail link for a file.
  """
  def get_thumbnail_url(file, token)  do
    token = keys_to_atoms(token)
    token = struct(OAuth2.AccessToken, token)
    client = Map.put(client(), :token, token)

    try do
      response = OAuth2.Client.get!(client, "https://www.googleapis.com/drive/v2/files/" <> file.path <> "?&fields=thumbnailLink")
      %{"thumbnailLink" => url} = response.body
      url
    rescue
      e -> :error
    end
  end

  # Authorization Strategy callbacks
  # Used internally by OAuth2 implementation

  def authorize_url(client, params) do
    AuthCode.authorize_url(client, params)
  end

  def get_token(client, params, headers) do
    client
    |> put_header("Accept", "application/json")
    |> AuthCode.get_token(params, headers)
  end

  def keys_to_atoms(string_key_map) when is_map(string_key_map) do 
    for {key, val} <- string_key_map, into: %{}, do: {String.to_atom(key), keys_to_atoms(val)} 
  end 
  def keys_to_atoms(value), do: value
end
