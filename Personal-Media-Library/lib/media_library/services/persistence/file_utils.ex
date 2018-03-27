defmodule MediaLibrary.FileUtils do
  @moduledoc """
  Provides an interface to upload files and retrive their
  streaming url.

  Chooses an appropriate method to store/retrieve files based
  on current storage_mode define in config files.

  TODO: Store file origin in the database and use it instead of
  storage_mode to choose the proper method.
  """

  alias MediaLibrary.LocalFileUtils
  alias MediaLibrary.S3Utils 
  alias MediaLibrary.OAuth.Google

  @storage_mode Application.get_env(:media_library, :storage_mode)

  @doc """
  Uploads file to the storage.
  """
  def upload_file(file, user, %{path: temp_path}) do
    case @storage_mode do
      :local ->
        LocalFileUtils.upload_file(file, temp_path)
      :s3 ->
        S3Utils.upload_file(file, user, temp_path)
    end
  end
  
  @doc """
  Deletes file from the storage.
  """
  def delete_file(file, user) do
    case @storage_mode do
      :local ->
        LocalFileUtils.delete_file(file)
      :s3 ->
        S3Utils.delete_file(file, user)
    end
  end

  @doc """
  Returns a URL used as a video source for streaming.
  """
  def build_file_url(file, user) do
    case file.origin do
      "drive" ->
        token = user.access_keys["google"]
        Google.get_file_url(file, token)
      _ ->
        case @storage_mode do
          :local ->
            LocalFileUtils.build_file_url(file)
          :s3 ->
            S3Utils.build_file_url(file, user)
        end
    end
  end

  @doc """
  Returns a URL used as an image source for thumbnail.
  """
  def build_thumbnail_url(file, user) do
    placeholder = "http://placehold.it/220x165/000/fff"

    case file.origin do
      "drive" ->
        token = user.access_keys["google"]
        case Google.get_thumbnail_url(file, token) do
          :error ->
            placeholder
          url ->
            url      
        end
      "S3" ->
        if file.is_adaptive do
          S3Utils.build_thumbnail_url(file, user)
        else
          placeholder
        end
      _ ->
        placeholder   
    end  
  end

end