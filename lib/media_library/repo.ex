defmodule MediaLibrary.Repo do
  @moduledoc """
  Provides an interface to MongoDB database functioning
  similarly to Ecto.Repo module.
  """

  @doc """
  Fetches all entries from the collection.
  
  Returns a list of structs.
  """
  def all(schema) do
    Mongo.find(:mongo, schema.collection, %{})
      |> Enum.to_list
      |> Enum.map(&schema.map_to_struct/1)
  end

  @doc """
  Fetches a single struct with matching id.
  
  Returns a struct if successful.
  Raises Ecto.NoResultsError if no record was found.
  """
  def get!(schema, id) do
    case Mongo.find_one(:mongo, schema.collection, %{"_id" => %BSON.ObjectId{value: id}}) do
      nil ->
        raise Ecto.NoResultsError, queryable: schema.collection
      result ->
        result |> schema.map_to_struct
    end
  end

  @doc """
  Fetches a single struct with matching parameters.

  Returns a struct if successful.
  Returns nil if no match found.
  """
  def get_by(schema, params) do
    case Mongo.find_one(:mongo, schema.collection, params) do
      nil ->
        nil
      result ->
        result |> schema.map_to_struct
    end
  end

  @doc """
  Inserts a struct.
  
  Returns {:ok, struct} if successful.
  Returns {:error, changeset} if failed.
  """
  def insert(changeset) do
    schema = changeset.data.__struct__
    changes = filter_out_virtual_fields(schema, changeset)

    case Mongo.insert_one(:mongo, schema.collection, changes) do
      {:ok, id} ->
        struct = 
          Ecto.Changeset.put_change(changeset, :id, id.inserted_id.value)    
          |> Ecto.Changeset.apply_changes()

        {:ok, struct}
      _ ->
        {:error, changeset}
    end
  end

  @doc """
  Applies changes from changeset to an existing record.
  
  Returns {:ok, struct} if successful.
  Returns {:error, changeset} if failed.
  """
  def update(changeset) do
    schema = changeset.data.__struct__
    changes = filter_out_virtual_fields(schema, changeset)

    case Mongo.update_one(:mongo, schema.collection,
      %{"_id" => %BSON.ObjectId{value: changeset.data.id}}, 
      %{"$set" => changes}) do
        {:ok, %{matched_count: 1}} ->
          {:ok, Ecto.Changeset.apply_changes(changeset)}
        _ ->
          {:error, changeset}
    end
  end

  @doc """
  Updates a nested property with path specified by <property>.
  
  Returns {:ok, struct} if successful.
  Returns {:error, struct} if failed.
  """
  def update_property(struct, property, value) do
    schema =  struct.__struct__

    case Mongo.update_one(:mongo, schema.collection,
      %{"_id" => %BSON.ObjectId{value: struct.id}}, 
      %{"$set" => %{property => value}}) do
        {:ok, %{matched_count: 1}} ->
          {:ok, struct}
        _ ->
          {:error, struct}
     end
  end

  @doc """
  Adds an object defined by changeset to an array property of the parent object.

  Arguments:
    changeset: object to insert
    struct:    parent struct
    property:  array property name on parent
  
  Returns {:ok, struct} if successful.
  Returns {:error, changeset} if failed.
  """
  def add_to_array(changeset, struct, property) do
    if(changeset.valid?) do
      parent_schema =  struct.__struct__

      nested_schema = changeset.data.__struct__
      changes = filter_out_virtual_fields(nested_schema, changeset)

      case Mongo.update_one(:mongo, parent_schema.collection,
        %{"_id" => %BSON.ObjectId{value: struct.id}}, 
        %{"$push" => %{property => changes}}) do
          {:ok, %{matched_count: 1}} ->
            {:ok, Ecto.Changeset.apply_changes(changeset)}
          _ ->
            {:error, changeset}
      end
    else
      Ecto.Changeset.apply_action(changeset, :insert)
    end
  end

  @doc """
  Updates an object defined by changeset located in an array property of the parent object.

  Arguments:
    changeset: object to update
    struct:    parent struct
    property:  array property name on parent
  
  Returns {:ok, struct} if successful.
  Returns {:error, changeset} if failed.
  """
  def update_in_array(changeset, struct, property) do
    parent_schema =  struct.__struct__
    nested_schema = changeset.data.__struct__

    changes = for {k, v} <- filter_out_virtual_fields(nested_schema, changeset), 
                            into: %{}, 
                            do: {property <> ".$." <> Atom.to_string(k), v}

    case Mongo.update_one(:mongo, parent_schema.collection,
      %{"_id" => %BSON.ObjectId{value: struct.id}, property <> ".id" => changeset.data.id}, 
      %{"$set" => changes}) do
        {:ok, %{matched_count: 1}} ->
          {:ok, Ecto.Changeset.apply_changes(changeset)}
        _ ->
          {:error, changeset}
    end
  end

  @doc """
  Deletes an object from an array property of the parent object.

  Arguments:
    struct:         object to delete
    parent_struct:  parent struct
    property:       array property name on parent
  
  Returns {:ok, struct} if successful.
  Returns {:error, changeset} if failed.
  """
  def delete_from_array(struct, parent_struct, property) do
    parent_schema =  parent_struct.__struct__
    nested_schema = struct.__struct__

    case Mongo.update_one(:mongo, parent_schema.collection,
      %{"_id" => %BSON.ObjectId{value: parent_struct.id}}, 
      %{"$pull" => %{property => %{id: struct.id}}}) do
        {:ok, %{matched_count: 1}} ->
          {:ok, struct}
        _ ->
          {:error, nested_schema.changeset(struct, %{})}
    end
  end

  @doc """
  Deletes a struct.

  Returns {:ok, struct} if successful.
  Returns {:error, changeset} if failed.
  """
  def delete(struct) do
    schema = struct.__struct__

    case Mongo.delete_one(:mongo, schema.collection, %{"_id" => %BSON.ObjectId{value: struct.id}}) do
      {:ok, %{deleted_count: 1}} ->
        {:ok, struct}
      _ ->
        {:error, schema.changeset(struct, %{})}
    end
  end

  
  # Filters out fields marked :virtual in the schema from
  # the changeset to avoid storing them in the database. 
  defp filter_out_virtual_fields(model, changeset) do
    non_virtual_fields = model.__schema__(:fields) 
    Map.take(changeset.changes, non_virtual_fields)
  end

end