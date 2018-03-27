defmodule MediaLibrary.Accounts.User do
  @moduledoc """
  User schema.

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

  alias MediaLibrary.Accounts.User
  alias MediaLibrary.Videos.Video

  # Collection and schema name.
  @collection "users"

  @primary_key {:id, :binary_id, autogenerate: true}
  schema @collection do
    field :email, :string
    field :name, :string
    field :password, :string, virtual: true
    field :password_hash, :string
    field :access_keys, :map

    embeds_many :videos, Video
  end

  @doc false
  def changeset(user, attrs) do
    user
      |> cast(attrs, [:email, :name, :password, :access_keys])
      |> validate_required([:email, :name])
      |> validate_format(:email, ~r/@/)
      |> unique_constraint(:email) # Implement on database side
      |> put_pass_hash()
  end
 
  # Converts user password to a password hash stored 
  # in the database and adds it into changeset.
  defp put_pass_hash(changeset) do
    case changeset do
      %Ecto.Changeset{valid?: true, changes: %{password: pass}} ->
        put_change(changeset, :password_hash, Comeonin.Pbkdf2.hashpwsalt(pass))
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
  a User struct.
  """
  def map_to_struct(user_map) do
    %User{
      id:    user_map["_id"].value,
      email: user_map["email"],
      name: user_map["name"],
      password_hash: user_map["password_hash"],
      access_keys: user_map["access_keys"],
      videos: map_videos(user_map["videos"])
    }
  end    

  defp map_videos(video_map_array) do
    if video_map_array != nil do
      Enum.map(video_map_array, &Video.map_to_struct/1)
    else
      []
    end
  end
end