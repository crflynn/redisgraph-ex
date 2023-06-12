defmodule RedisGraph.Util do
  @moduledoc "Provides utility functions for RedisGraph modules."

  @doc """
  Generate a random string of characters `a-z` of length `n`.

  This is used to create a random alias for a node or relationship if one is not already set.
  """
  @spec random_string(pos_integer()) :: String.t()
  def random_string(n \\ 10) do
    1..n
    |> Enum.reduce("", fn _, acc -> acc <> to_string(Enum.take_random(?a..?z, 1)) end)
  end

  @doc """
  Converts properties map into string representation. Otherwise returns empty string.

  This is used to serialize edisGraph.Node or RedisGraph.Relationship properties
  into strings when preparing redisgraph queries.

  ## Example
  ```
  alias RedisGraph.{Node, Util}

  bob = Node.new(%{
    alias: :n,
    labels: ["person"],
    properties: %{
      name: "Bob Thomsen",
      age: 22
    }
  })

  bob_properties = Util.properties_to_string(bob.properties)

  ```
  """
  @spec properties_to_string(map() | any()) :: String.t()
  def properties_to_string(properties) do
    props =
      if is_map(properties) and map_size(properties) > 0 do
        Stream.map(properties, fn {k, x} -> "#{k}: #{value_to_string(x)}" end)
        |> Enum.join(", ")
      else
        ""
      end

    case String.length(props) do
      0 -> ""
      _ -> " {#{props}}"
    end
  end

  @doc """
  Converts labels list into string representation. Otherwise returns empty string.

  This is used to serialize RedisGraph.Node labels into strings when preparing redisgraph queries.

  ## Example
  ```
  alias RedisGraph.{Node, Util}

  bob = Node.new(%{
    alias: :n,
    labels: ["person", "student"],
    properties: %{
      name: "Bob Thomsen",
      age: 22
    }
  })

  bob_labels = Util.labels_to_string(bob.labels)

  ```
  """
  @spec labels_to_string(list(String.t()) | any()) :: String.t()
  def labels_to_string(labels) do
    if is_list(labels) and length(labels) > 0 do
      ":" <> Enum.join(labels, ":")
    else
      ""
    end
  end

  @doc """
  Converts labels list into string representation. Otherwise returns empty string.

  This is used to serialize RedisGraph.Node labels into strings when preparing redisgraph queries.

  ## Example
  ```
  alias RedisGraph.{Relationship, Util}

  relationship = Relationship.new(%{
    src_node: 1,
    dest_node: 2,
    type: "friend",
    properties: %{
      best_friend: true
    }
  })
  relationship_type = Util.type_to_string(relationship.type)

  ```
  """
  @spec type_to_string(list(String.t()) | any()) :: String.t()
  def type_to_string(type) do
    if is_binary(type) and String.length(type) > 0 do
      ":" <> type
    else
      ""
    end
  end

  @doc """
  Converts received value into string representation.

  This is used to serialize value into strings when preparing redisgraph queries.

  ## Example
  ```
  alias RedisGraph.{Node, Util}

  list_to_string = Util.value_to_string(["test", 11, 12.12, false, nil, ["hi", "bye"], %{me: "you"}])
  ```
  """
  @spec value_to_string(any()) :: String.t()
  def value_to_string(val) do
    cond do
      # check if string contains function
      is_binary(val) and String.contains?(val, "(") and String.contains?(val, ")") ->
        val

      is_binary(val) and String.length(val) > 0 ->
        "'" <> val <> "'"

      is_number(val) ->
        "#{val}"

      is_boolean(val) ->
        "#{val}"

      is_nil(val) ->
        "null"

      is_atom(val) ->
        Atom.to_string(val)

      is_list(val) ->
        "[#{Stream.map(val, fn individual_value -> value_to_string(individual_value) end) |> Enum.join(", ")}]"

      is_map(val) ->
        "{#{Stream.map(val, fn {k, x} -> "#{k}: #{value_to_string(x)}" end) |> Enum.join(", ")}}"

      true ->
        "#{val}"
    end
  end
end
