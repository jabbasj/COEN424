defmodule MediaLibrary.DownloadManager do
  alias MediaLibrary.FileUtils
  alias MediaLibrary.S3Utils
  alias MediaLibrary.Transcoder

  require Logger

  def start_download(user, id, video) do
    Task.Supervisor.start_child(MediaLibrary.TaskSupervisor, __MODULE__, :download_from_drive, [user, id, video])
    # Must initialize S3 multi-part upload here
    # TODO: Add some sort of LOCK/Check to avoid downloading the same file at the same time....
  end

 # Downloads drive video to ./TEMP/{user_email}/{video_id}
  def download_from_drive(user, id, video) do
    Logger.info "Initiating copying to S3..." 

    temp_dir = Path.join([Path.expand("./TEMP/"), user.email])
    File.mkdir_p(temp_dir)
    filename = Path.join([temp_dir, video.id])

    video_url = FileUtils.build_file_url(video, user)
    redirect_url = HTTPotion.get(video_url).headers["location"]   #google drive always redirecting

    #TODO: error handling (if token invalid or if we don't get redirect)
    Logger.info "Starting download from Drive"
    from(redirect_url, [path: filename]) 

    #This can't be called here if we want to stream-upload to S3
    Task.Supervisor.start_child(MediaLibrary.TaskSupervisor, __MODULE__, :upload_to_s3, [id, filename, user, video])    
  end


# Uploads video to DRIVE_COPY/{id}{extension}
# TODO: Stream upload while file is being downloaded
  def upload_to_s3(_id, path, user, video) do
    Logger.info "Starting upload to S3"

    video = %{video | path: video.id <> Path.extname(video.filename)}

    S3Utils.upload_file(video, user, path)

    # Delete TEMP file
    File.rm(path)

    #TODO:    
    # Send a signal that the S3 copy is ready?
    # Update video path/origin to S3?
    Transcoder.start_transcoding_job(user, video)
  end

  # FOR ILYA:
  # See TODO below (in handle_async_response_chunk) for access to chunked binary contents in-memory (before saving to file)

  # FOLLOWING CODE COPIED FROM: https://github.com/asiniy/download/blob/master/lib/download.ex
  @default_max_file_size 1024 * 1024 * 1000 # 1 GB

  def from(url, opts \\ []) do
    max_file_size = Keyword.get(opts, :max_file_size, @default_max_file_size)
    file_name = url |> String.split("/") |> List.last()
    path = Keyword.get(opts, :path, get_default_download_path(file_name))

    with  { :ok, file } <- create_file(path),
          { :ok, response_parsing_pid } <- create_process(file, max_file_size, path),
          { :ok, _pid } <- perform_download(url, response_parsing_pid, path),
          { :ok } <- wait_for_download(),
        do: { :ok, path }
  end

  defp get_default_download_path(file_name) do
    System.cwd() <> "/" <> file_name
  end

  defp create_file(path), do: File.open(path, [:write, :exclusive])
  defp create_process(file, max_file_size, path) do
    opts = %{
      file: file,
      max_file_size: max_file_size,
      controlling_pid: self(),
      path: path,
      downloaded_content_length: 0
    }
    { :ok, spawn_link(__MODULE__, :do_download, [opts]) }
  end

  defp perform_download(url, response_parsing_pid, path) do
    request = HTTPoison.get url, %{}, stream_to: response_parsing_pid

    case request do
      { :error, _reason } ->
        File.rm!(path)
      _ -> nil
    end

    request
  end

  defp wait_for_download() do
    receive do
      reason -> reason
    end
  end

  alias HTTPoison.{AsyncHeaders, AsyncStatus, AsyncChunk, AsyncEnd}

  @wait_timeout 5000

  @doc false
  def do_download(opts) do
    receive do
      response_chunk -> handle_async_response_chunk(response_chunk, opts)
    after
      @wait_timeout -> { :error, :timeout_failure }
    end
  end

  defp handle_async_response_chunk(%AsyncStatus{code: 200}, opts), do: do_download(opts)
  defp handle_async_response_chunk(%AsyncStatus{code: status_code}, opts) do
    finish_download({ :error, :unexpected_status_code, status_code }, opts)
  end

  defp handle_async_response_chunk(%AsyncHeaders{headers: headers}, opts) do
    content_length_header = Enum.find(headers, fn({ header_name, _value }) ->
      header_name == "Content-Length"
    end)

    do_handle_content_length(content_length_header, opts)
  end

  #TODO: Instead of writing to file, upload chunk to S3
  defp handle_async_response_chunk(%AsyncChunk{chunk: data}, opts) do
    downloaded_content_length = opts.downloaded_content_length + byte_size(data)

    if downloaded_content_length < opts.max_file_size do
      IO.binwrite(opts.file, data) #TODO: Instead of writing to file, upload chunk to S3
      opts_with_content_length_increased = Map.put(opts, :downloaded_content_length, downloaded_content_length)
      do_download(opts_with_content_length_increased)
    else
      finish_download({ :error, :file_size_is_too_big }, opts)
    end
  end

  defp handle_async_response_chunk(%AsyncEnd{}, opts), do: finish_download({ :ok }, opts)

  # Uncomment one line below if you are prefer to test not "Content-Length" header response, but a real file size
  # defp do_handle_content_length(_, opts), do: do_download(opts)
  defp do_handle_content_length({ "Content-Length", content_length }, opts) do
    if String.to_integer(content_length) > opts.max_file_size do
      finish_download({ :error, :file_size_is_too_big }, opts)
    else
      do_download(opts)
    end
  end
  defp do_handle_content_length(nil, opts), do: do_download(opts)

  defp finish_download(reason, opts) do
    File.close(opts.file)
    if (elem(reason, 0) == :error) do
      File.rm!(opts.path)
    end
    send(opts.controlling_pid, reason)
  end

end