defmodule MediaLibrary.OAuth do
  @moduledoc """
  Provides an interface to OAuth.

  Choses appropriate implementation based on the provider.
  """

  alias MediaLibrary.OAuth.Google

  @doc """
  Returns an authorization site url based on the provider.
  """
  def authorize_url!("google") do
    Google.authorize_url!(scope: "email profile", 
                          access_type: "offline", 
                          include_granted_scopes: "true",
                          state: "login")
  end
  def authorize_url!("drive") do
    Google.authorize_url!(scope: "email profile https://www.googleapis.com/auth/drive", 
                          access_type: "offline", 
                          include_granted_scopes: "true",
                          state: "drive")
  end
  def authorize_url!(_), do: raise "No matching provider available"
  
  @doc """
  Gets an access token from an Authorization Code from the provider.
  """
  def get_token!("google", code), do: Google.get_token!(code: code)
  def get_token!(_, _), do: raise "No matching provider available"
  
  @doc """
  Gets information about the authorized user from the provider using
  an access token.
  """
  def get_user_params!("google", token), do: Google.get_user_params(token)
  def get_user_params!(_, _), do: raise "No matching provider available"  

  @doc """
  Gets information about the authorized user from the provider using
  an access token.
  """
  def get_files!("google", token), do: Google.get_drive_files(token)
  def get_files!(_, _), do: raise "No matching provider available"  
end