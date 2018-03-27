defmodule MediaLibraryWeb.VideoController do
  require Logger
  use MediaLibraryWeb, :controller

  alias MediaLibrary.Videos
  alias MediaLibrary.Videos.Video
  alias MediaLibrary.FileUtils
  alias MediaLibrary.Transcoder
  alias MediaLibrary.DownloadManager

  def action(conn, _) do
    apply(__MODULE__, action_name(conn),
      [conn, conn.params, conn.assigns.current_user])
  end

  def index(conn, _params, user) do
    videos = Videos.list_videos(user) |> Enum.sort(&(&1.title < &2.title))
    render(conn, "index.html", videos: videos, user: user)
  end

  def new(conn, _params, _user) do
    changeset = Videos.change_video(%Video{})
    render(conn, "new.html", changeset: changeset)
  end

  def create(conn, %{"video" => video_params}, user) do
    case Videos.create_video(user, video_params) do
      {:ok, video} ->
        FileUtils.upload_file(video, user, video_params["video_file"])        

        conn
        |> put_flash(:info, "Video created successfully.")
        |> redirect(to: video_path(conn, :show, video))
      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "new.html", changeset: changeset)
    end
  end

  def show(conn, %{"id" => id}, user) do
    video = Videos.get_video!(user, id)
    video_url = FileUtils.build_file_url(video, user)

    {:ok, response} = HTTPoison.head(video_url, [], follow_redirect: true);
    
    cond do 
      response.status_code == 404 ->
        conn
        |> put_flash(:error, "Video source is deleted or not accessible. Try re-syncing external storage.")
        |> render("show.html", video: video, video_url: video_url)
      video.is_transcoding ->
        conn
        |> put_flash(:info, "Video is transcoding... After transcoding is complete, next page refresh will update the player.")
        |> render("show.html", video: video, video_url: video_url)
      true ->
        render(conn, "show.html", video: video, video_url: video_url)
    end
  end

  def info(conn, %{"id" => id}, user) do
    video = Videos.get_video!(user, id)
    render(conn, "info.html", video: video)
  end

  def edit(conn, %{"id" => id}, user) do
    video = Videos.get_video!(user, id)
    changeset = Videos.change_video(video)
    render(conn, "edit.html", video: video, changeset: changeset)
  end

  def transcode(conn, %{"id" => id}, user) do
    video = Videos.get_video!(user, id)

    if video.origin == "drive" do
      Videos.update_video(user, video, %{is_transcoding: true})
      download_from_drive(conn, user, id, video)
    else 
      Transcoder.start_transcoding_job(user, video)

      conn
      |> redirect(to: video_path(conn, :show, video))
    end
  end

def update(conn, %{"id" => id, "video" => video_params}, user) do
    video = Videos.get_video!(user, id)

    case Videos.update_video(user, video, video_params) do
      {:ok, video} ->
        conn
        |> put_flash(:info, "Video updated successfully.")
        |> redirect(to: video_path(conn, :show, video))
      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "edit.html", video: video, changeset: changeset)
    end
  end

  def delete(conn, %{"id" => id}, user) do
    video = Videos.get_video!(user, id)
    {:ok, _video} = Videos.delete_video(user, video)
    FileUtils.delete_file(video, user)

    conn
    |> put_flash(:info, "Video deleted successfully.")
    |> redirect(to: video_path(conn, :index))
  end

  # Downloads drive video to ./TEMP/{user_email}/{video_id}.mp4
  defp download_from_drive(conn, user, id, video) do
    # Check if download is already in-progress
    temp_dir = Path.join([Path.expand("./TEMP/"), user.email])
    File.mkdir_p(temp_dir)
    filename = Path.join([temp_dir, video.id])

    if (File.exists?(filename)) do 
      conn 
      |> put_flash(:error, "File is already being transcoded!")
      |> redirect(to: video_path(conn, :index))
    else
      #Start download from drive to s3
      DownloadManager.start_download(user, id, video)

      conn
      |> redirect(to: video_path(conn, :show, video))
    end
  end
end
