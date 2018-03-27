defmodule MediaLibraryWeb.StreamController do
  @moduledoc """
  Controller for streaming videos from local storage.
  """

  use MediaLibraryWeb, :controller

  alias MediaLibrary.Videos
  alias MediaLibrary.LocalFileUtils, as: FileUtils

  def stream(%{req_headers: headers} = conn, %{"id" => id}) do
    video = Videos.get_video!(conn.assigns.current_user, id)
    send_video(conn, headers, video)
  end

  @doc """
  Sends video starting from requested offset. 
  """
  def send_video(conn, headers, video) do
    video_path = FileUtils.build_file_path(video)

    file_size = FileUtils.get_file_size(video_path)
    offset = FileUtils.get_offset(headers)

    conn
    |> Plug.Conn.put_resp_header("content-type", video.content_type)
    |> Plug.Conn.put_resp_header("content-range", "bytes #{offset}-#{file_size-1}/#{file_size}")
    |> Plug.Conn.send_file(206, video_path, offset, file_size - offset)
  end

end