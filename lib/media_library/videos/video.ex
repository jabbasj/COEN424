defmodule MediaLibrary.Videos.Video do
  @moduledoc """
  Video schema.

  Since default Ecto Repo is not used, additional changes
  have to be made to support MongoDB. Thus, special 
  conventions for defining schemas have been created.

  Every schema has to implement two functions:

    1. collection() - return the name of MongoDB collection.
    2. map_to_struct(map) - converts a map returned from 
    MongoDB to a struct of schema type.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias MediaLibrary.Videos.Video

  # Collection and schema name.
  @collection "videos"

  @primary_key {:id, :binary_id, autogenerate: true}
  schema @collection do
    field :title, :string
    field :video_file, :any, virtual: true
    field :filename, :string
    field :content_type, :string
    field :path, :string
    field :origin, :string
    field :is_adaptive, :boolean
    field :is_transcoding, :boolean
  end

  @doc false
  def changeset(video, attrs) do
    video
      |> cast(attrs, [:title, :video_file, :filename, :content_type, :path, :origin, :is_adaptive, :is_transcoding])
      |> validate_required([:title])
      |> put_video_file_data()
      |> validate_change(:content_type, fn :content_type, content_type -> validate_content_type(content_type) end)
  end

  # Validates content type of uploaded file
  defp validate_content_type(content_type) do
    if Kernel.match?("video" <> _extension, content_type) do
      []
    else
      [video_file: "Wrong file format. Input file must be a video."]
    end
  end
 
  # Extracts all relevant attributes from video_file
  # and adds them into changeset.
  defp put_video_file_data(changeset) do
    case changeset do
      %Ecto.Changeset{valid?: true, changes: %{video_file: video_file}} ->
        id = Ecto.UUID.generate() 
        path = id <> Path.extname(video_file.filename)
        
        changeset
        |> put_change(:id, id)
        |> put_change(:path, path)
        |> put_change(:filename, video_file.filename)
        |> put_change(:content_type, video_file.content_type)
      %Ecto.Changeset{valid?: true, changes: %{origin: "drive"}} ->
        id = Ecto.UUID.generate() 
        
        changeset
        |> put_change(:id, id)
      _ ->
        changeset
    end
  end

  # MongoDB support

  @doc """
  Returns the collection name.
  """
  def collection do
    @collection
  end

  @doc """
  Converts a map returned from MongoDB to 
  a Video struct.
  """
  def map_to_struct(video_map) do
    %Video{
      id:    video_map["id"],
      title: video_map["title"],
      filename: video_map["filename"],
      content_type: video_map["content_type"],
      path: video_map["path"],
      origin: video_map["origin"],
      is_adaptive: video_map["is_adaptive"],
      is_transcoding: video_map["is_transcoding"]
    }
  end    
end