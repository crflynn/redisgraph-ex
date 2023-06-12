defmodule RedisGraph.Relationship do
  @moduledoc """
  An Relationship component relating two Nodes in a Graph.

  Relationships must have a source node and destination node, describing a relationship
  between two entities in a Graph. Nodes can be represented either as
  Node structures(%RedisGraph.Node{}) or id(integer) of respective node.

  Relationships must have a type which identifies the type of relationship being
  described between entities.

  Relationships, like Nodes, may also have properties, a map of values which describe
  attributes of the relationship between the associated Nodes.
  """
  alias RedisGraph.Util

  @type t() :: %__MODULE__{
          id: integer(),
          alias: atom(),
          src_node: Node.t() | number(),
          dest_node: Node.t() | number(),
          type: String.t(),
          properties: %{optional(String.t()) => any()}
        }

  @enforce_keys [:src_node, :dest_node, :type]
  defstruct [:id, :alias, :src_node, :dest_node, :type, properties: %{}]

  @doc """
  Create a new Relationship from provided argument.
  Argument should be a map and key: `type` with value of String type is required.

  ## Example
  ```
  alias RedisGraph.{Node, Relationship}

  john = Node.new(%{
    labels: ["person"],
    properties: %{
      name: "John Doe"
    }
  })

  bob = Node.new(%{
    labels: ["person"],
    properties: %{
      name: "Bob Nilson"
    }
  })

  relationship = Relationship.new(%{
    src_node: john,
    dest_node: bob,
    type: "friend",
    properties: %{
      best_friend: true
    }
  })
  ```
  """
  @spec new(map()) :: t()
  def new(%{type: type} = map) when is_binary(type) do
    relationship = struct(__MODULE__, map)
    if(is_nil(relationship.alias), do: set_alias_if_nil(relationship), else: relationship)
  end

  @spec set_alias_if_nil(t()) :: t()
  def set_alias_if_nil(relationship) do
    if is_nil(relationship.alias) do
      alias = Util.random_string() |> String.to_atom()
      %{relationship | alias: alias}
    else
      relationship
    end
  end

  @doc """
  Compare two relationships with respect to equality.

  Comparison logic:

  * If the ids differ, returns ``false``
  * If the source nodes differ, returns ``false``
  * If the destination nodes differ, returns ``false``
  * If the types differ, returns ``false``
  * If the properties differ, returns ``false``
  * Otherwise returns `true`
  """
  @spec compare(t(), t()) :: boolean()
  def compare(left, right) do
    cond do
      left.id != right.id -> false
      left.src_node != right.src_node -> false
      left.dest_node != right.dest_node -> false
      left.type != right.type -> false
      map_size(left.properties) != map_size(right.properties) -> false
      not Map.equal?(left.properties, right.properties) -> false
      true -> true
    end
  end
end
