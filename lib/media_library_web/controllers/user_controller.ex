defmodule MediaLibraryWeb.UserController do
  @moduledoc """
  Controller responsible for account registration.
  """
  use MediaLibraryWeb, :controller
  alias MediaLibrary.Accounts
  alias MediaLibraryWeb.Auth
  alias MediaLibrary.Videos

  def new(conn, _params) do
    changeset = Accounts.change_user()
    render conn, "new.html", changeset: changeset
  end

  def create(conn, %{"user" => user_params}) do
    case Accounts.create_user(user_params) do
      {:ok, user} ->
        conn
        |> Auth.login(user)
        |> put_flash(:info, "You have been successfully registered!")
        |> redirect(to: video_path(conn, :index))
      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "new.html", changeset: changeset)
    end
  end

  def settings(conn, _params) do
    user = conn.assigns.current_user
    access_keys = user.access_keys
    drive_associated = get_in(access_keys, ["google", "has_drive"]) == true

    render conn, "settings.html", drive_associated: drive_associated
  end

  def associate_drive(conn, %{"provider" => provider, "user_params" => user_params, "token" => token}) do
    token = Map.put(token, :has_drive, true) |> Map.from_struct

    user = conn.assigns.current_user
    case user.access_keys[provider] do
      nil ->
        user_params = Map.put(user, :access_keys, %{provider => token}) |> Map.from_struct
        Accounts.update_user(user, user_params)
      _ ->
        Accounts.update_access_key(user, provider, token)
    end

    redirect(conn, to: user_path(conn, :settings))
  end

  @doc """
  Adds new Drive Videos to library.
  """
  def sync_library(conn, %{"provider" => "drive"}) do
    user = conn.assigns.current_user
    token = user.access_keys["google"]
    
    videos = MediaLibrary.OAuth.get_files!("google", token).body["items"]
    
    attrs =
      videos
      |> Enum.map(&get_video_attrs/1)
      |> Enum.filter(fn attrs -> not is_in_user_videos?(user.videos, attrs) end)
      
    Enum.each(attrs, fn a -> MediaLibrary.Videos.create_video(user, a) end)

    removed_vids = remove_old_videos(user, videos)

    conn 
    |> put_flash(:info, "Sync completed. #{length attrs} new files added to the library. #{length removed_vids} old file removed.")
    |> render("settings.html", drive_associated: true)
  end


  def remove_old_videos(user, drive_videos) do

    drive_video_attrs =
      drive_videos
      |> Enum.map(&get_video_attrs/1)

    old_drive_videos = 
      user.videos
      |> Enum.filter(fn vid -> vid.origin == "drive" end)
      |> Enum.filter(fn old -> not is_in_drive?(drive_video_attrs, old.path) end)

    Enum.each(old_drive_videos, fn vid -> Videos.delete_video(user, Videos.get_video!(user, vid.id)) end)    

    old_drive_videos
  end

  defp get_video_attrs(video) do
    %{
      title: video["title"],
      filename: video["originalFilename"],
      content_type: video["mimeType"],
      path: video["id"],
      origin: "drive"
    }
  end

  defp is_in_user_videos?(user_videos, attrs) do
    Enum.any?(user_videos, fn v -> 
      (v.origin == "drive" || v.is_adaptive) && v.filename == attrs.filename 
    end)
  end

  defp is_in_drive?(drive_videos, path) do
    Enum.any?(drive_videos, fn v -> v.path == path end)
  end

end
