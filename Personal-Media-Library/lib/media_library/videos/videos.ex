defmodule MediaLibrary.Videos do
  @moduledoc """
  The Videos context. Represents videos belonging to users.
  """

  import Ecto.Query, warn: false

  alias MediaLibrary.Videos.Video
  alias MediaLibrary.Repo

  alias MediaLibrary.Accounts

  @doc """
  Returns the list of videos belonging to user.

  ## Examples

      iex> list_videos(user)
      [%Video{}, ...]

  """
  def list_videos(user) do
    user = Accounts.get_user(user.id)
    user.videos
  end
  
  @doc """
  Gets a single video.

  Raises if the Video does not exist.

  ## Examples

      iex> get_video!(user, 123)
      %Video{}

  """
  def get_video!(user, id) do
    case Enum.find(user.videos, fn v -> v.id == id end) do
      nil ->
        raise "Error: Video not found"
      video ->
        video
    end
  end

  @doc """
  Creates a video.

  ## Examples

      iex> create_video(user, %{field: value})
      {:ok, %Video{}}

      iex> create_video(user, %{field: bad_value})
      {:error, ...}

  """
  def create_video(user, attrs) do
    %Video{}
    |> Video.changeset(attrs)
    |> Repo.add_to_array(user, "videos")
  end

  @doc """
  Updates a video.

  ## Examples

      iex> update_video(user, video, %{field: new_value})
      {:ok, %Video{}}

      iex> update_video(user, video, %{field: bad_value})
      {:error, ...}

  """
  def update_video(user, %Video{} = video, attrs) do
    video
    |> Video.changeset(attrs)
    |> Repo.update_in_array(user, "videos")
  end

  @doc """
  Deletes a Video.

  ## Examples

      iex> delete_video(user, video)
      {:ok, %Video{}}

      iex> delete_video(user, video)
      {:error, ...}

  """
  def delete_video(user, %Video{} = video) do
    Repo.delete_from_array(video, user, "videos")
  end

  @doc """
  Returns a datastructure for tracking video changes.

  ## Examples

      iex> change_video(video)
      %Video{...}

  """
  def change_video(%Video{} = video) do
    Video.changeset(video, %{})
  end

end
