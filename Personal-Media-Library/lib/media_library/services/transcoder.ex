defmodule MediaLibrary.Transcoder do
  @moduledoc """
  Encapsulates access to Amazon Elastic Transcoder.
  """
  alias ExAws.ElasticTranscoder
  alias MediaLibrary.Videos

  require Logger

  @doc """
  Creates a new transcoding job on Amazon ET to convert source file
  to adaptive MPEG-DASH format.

  Returns JobID of the created job.
  """
  def start_transcoding_job(user, video) do
    user_id = Base.encode16(user.id, case: :lower)   

    key = user_id <> "/" <> video.path
    output_key_prefix = user_id <> "/" <> video.id <> "/"
    
    request_params = build_transcording_params(key, output_key_prefix)
    
    %{"Job" => %{"Id" => job_id}} = ElasticTranscoder.create_job(request_params) |> ExAws.request!()
    Logger.info("Transcoding job started!")

    Videos.update_video(user, video, %{is_transcoding: true})
    Task.Supervisor.start_child(MediaLibrary.TaskSupervisor, MediaLibrary.Transcoder, :poll_job_status, [job_id, user, video])
  end

  @doc """
  Checks status of the transcoding job every 15 seconds until Completed or Failed.

  If completed successfully, modifies database record to point to new the adaptive version. 
  If failed, raises an exception.
  """
  def poll_job_status(job_id, user, video) do
    %{"Job" => %{"Status" => status}} = ExAws.ElasticTranscoder.read_job(job_id) |> ExAws.request!()

    case status do
      "Complete" ->
        attrs =  %{is_adaptive: true, content_type: "application/dash+xml", is_transcoding: false, origin: "S3"};
        case Videos.update_video(user, video, attrs) do
          {:ok, _video} ->
            Logger.info("Transcoding job completed!")
          {:error, _reason} ->
            Logger.info("Transcoding completed, but updating video info failed. Video might be deleted. Cleaning up...")
            MediaLibrary.FileUtils.delete_file(Map.put(video, :is_adaptive, true), user)
        end      
      "Error" ->
        Videos.update_video(user, video, %{is_transcoding: false})
        raise "Transcoding job failed"
      _ ->
        Logger.info("Transcoding not completed... waiting for 15s")
        Process.sleep(15000)
        poll_job_status(job_id, user, video)
    end
  end

  defp build_transcording_params(key, output_key_prefix) do
    %{
      "Inputs" => [%{"Key" => key}],
      "OutputKeyPrefix" => output_key_prefix,
      "Outputs" => [
        build_output_params("600"),
        build_output_params("1200"),
        build_output_params("2400"),
        build_output_params("4800"),
        build_output_params("audio"),
      ],
      "Playlists" => [build_playlist_params()],
      "PipelineId" => "1509724700228-k1lmpm"
    }
  end

  defp build_playlist_params do
    %{
      "Format" => "MPEG-DASH",
      "Name" => "playlist",
      "OutputKeys" => [
        "600.mp4",
        "1200.mp4",
        "2400.mp4",
        "4800.mp4",
        "audio.mp4"
      ]
    }
  end

  defp build_output_params(quality) do
    params = %{
      "Key" => quality <> ".mp4",
      "PresetId" => get_preset_id(quality),
      "SegmentDuration" => "5" 
    }

    if quality == "4800" do
      Map.put(params, "ThumbnailPattern", "thumb-{count}")
    else
      params
    end
  end

  defp get_preset_id(quality) do
    case quality do
      "600" ->
        "1351620000001-500050"
      "1200" ->
        "1351620000001-500040"
      "2400" ->
        "1351620000001-500030"
      "4800" ->
        "1511662978593-fzoida"
      "audio" ->
        "1351620000001-500060"
      _ ->
        raise "Unsupported transcoding quality"
    end
  end
end