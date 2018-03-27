defmodule MediaLibrary.Accounts do
  alias MediaLibrary.Repo
  alias MediaLibrary.Accounts.User

  @doc """
  Returns a list of all users.
  """
  def list_users do
    Repo.all(User)
  end

  @doc """
  Finds user by id.
  """
  def get_user(id) do
    Repo.get!(User, id)
  end

  @doc """
  Finds user by properties.
  """
  def get_user_by(params) do
    Repo.get_by(User, params)
  end

  @doc """
  Creates a new user from attributes.
  """
  def create_user(attrs) do
    changeset = User.changeset(%User{}, attrs)
    case get_user_by(email: attrs["email"]) do
      nil ->
        Repo.insert(changeset)
      _user ->
        changeset 
        |> Ecto.Changeset.add_error(:email, "An account with this e-mail already exists")
        |> Ecto.Changeset.apply_action(:insert)
    end

  end

  @doc """
  Updates user from attributes.
  """
  def update_user(user, attrs) do
    user
    |> User.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Updates an access key for provider.

  Keeps the previous refresh token if it exists.
  """
  def update_access_key(user, provider, key) do
    refresh_token = get_in(user.access_keys, [provider, "refresh_token"])   
    key =
      case refresh_token do
        nil ->
          key
        value ->
          %{key | refresh_token: value}
      end

    # Hacked in, should be refactored
    has_drive = get_in(user.access_keys, [provider, "has_drive"])
    key =
    case has_drive do
      nil ->
        key
      _value ->
        Map.put(key, :has_drive, true)
    end

    property = "access_keys." <> provider
     
    Repo.update_property(user, property, key)
  end

  @doc """
  Creates a new user changeset.
  """
  def change_user(), do: change_user(%User{})
  def change_user(%User{} = user) do
    User.changeset(user, %{})
  end
end