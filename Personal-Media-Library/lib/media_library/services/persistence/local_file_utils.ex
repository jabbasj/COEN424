defmodule MediaLibrary.LocalFileUtils do
  @moduledoc """
  A helper module providing an interface to file system storage.

  Used for uploading files to local filesystem and retrieving 
  them for streaming.
  """

  import MediaLibraryWeb.Router.Helpers, only: [stream_path: 3]

  @doc """
  Uploads file to the upload directory.
  """
  def upload_file(file, temp_path) do
    file_path = build_file_path(file)
    unless File.exists?(file_path) do
      file_path |> Path.dirname() |> File.mkdir_p()
      File.copy!(temp_path, file_path)
    end
  end

  @doc """
  Deletes file from the upload directory.
  """
  def delete_file(file) do
    file_path = build_file_path(file)
    File.rm!(file_path)
  end

  @doc """
  Builds a URL pointing at the StreamingController to stream 
  local videos.
  """
  def build_file_url(file) do
    stream_path(MediaLibraryWeb.Endpoint, :stream, file.id)
  end

  @doc """
  Builds a file path by combining upload directory path
  specified in config.exs with the filename.
  """
  def build_file_path(file) do
    Application.get_env(:media_library, :upload_dir) |> Path.join(file.path)
  end
  
  @doc """
  Returns file size of file located at path.

  Throws if not successful.
  """
  def get_file_size(path) do
    {:ok, %{size: size}} = File.stat path
    size
  end

  @doc """
  Gets file offset requested by the browser.

  Parses the range header, extracting start position.
  """
  def get_offset(headers) do
    case List.keyfind(headers, "range", 0) do
      {"range", "bytes=" <> pos_range} ->
        start_pos = 
          String.split(pos_range, "-") 
          |> hd

        String.to_integer(start_pos)
      nil ->
        0
    end
  end

end