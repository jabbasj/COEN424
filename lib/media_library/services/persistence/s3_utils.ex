defmodule MediaLibrary.S3Utils do
  @moduledoc """
  A helper module providing an interface 
  for common S3 operations.
  """

  alias ExAws.S3
  
  @base_url Application.get_env(:media_library, :s3_url)
  @bucket   Application.get_env(:media_library, :s3_bucket)

  @doc """
  Uploads file to S3.
  """
  def upload_file(file, user, temp_path) do
    user_id = Base.encode16(user.id, case: :lower)   
    file_path = user_id <> "/" <> file.path

    %{status_code: 200} = 
      temp_path
      |> S3.Upload.stream_file
      |> S3.upload(@bucket, file_path)
      |> ExAws.request!
  end

  def upload_file_direct(s3_path, temp_path) do
      %{status_code: 200} = 
      temp_path
      |> S3.Upload.stream_file
      |> S3.upload(@bucket, s3_path)
      |> ExAws.request!    
  end

  @doc """
  Deletes object from S3.
  """
  def delete_file(file, user) do
    user_id = Base.encode16(user.id, case: :lower)   

    if file.is_adaptive do
      file_path = user_id <> "/" <> file.id
      
      %{body: %{contents: list}} = S3.list_objects("pml-storage", prefix: file_path) |> ExAws.request!  
      list = Enum.map(list, fn x -> x.key end)
      
      %{status_code: 200} = 
        S3.delete_multiple_objects(@bucket, list)
        |> ExAws.request!
    else
      file_path = user_id <> "/" <> file.path

      %{status_code: 204} = 
        S3.delete_object(@bucket, file_path)
        |> ExAws.request!
    end
  end

  @doc """
  Builds file URL used for streaming.
  """
  def build_file_url(file, user) do
    user_id = Base.encode16(user.id, case: :lower)   

    if file.is_adaptive do
      file_path = user_id <> "/" <> file.id <> "/" <> "playlist.mpd"
      @base_url <> @bucket <> "/" <> file_path
    else
      @base_url <> @bucket <> "/" <> user_id <> "/" <> file.path
    end 
  end

  @doc """
  Builds file URL used for thumbnails.

  Assumes file is transcoded.
  """
  def build_thumbnail_url(file, user) do
    user_id = Base.encode16(user.id, case: :lower)   
    file_path = user_id <> "/" <> file.id <> "/" <> "thumb-00001.png"
    @base_url <> @bucket <> "/" <> file_path
  end

  def list_files() do
    ExAws.S3.list_objects(@bucket) |> ExAws.request!
  end

end