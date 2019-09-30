defmodule RedisGraph.Edge do
  @moduledoc """
  An Edge component relating two Nodes in a Graph.

  Edges must have a source node and destination node, describing a relationship
  between two entities in a Graph. The nodes must exist in the Graph in order
  for the edge to be added.

  Edges must have a relation which identifies the type of relationship being
  described between entities

  Edges, like Nodes, may also have properties, a map of values which describe
  attributes of the relationship between the associated Nodes.
  """
  alias RedisGraph.Util

  @type t() :: %__MODULE__{
          id: integer(),
          src_node: Node.t() | number(),
          dest_node: Node.t() | number(),
          relation: String.t(),
          properties: %{optional(String.t()) => any()}
        }

  @enforce_keys [:src_node, :dest_node, :relation]
  defstruct [:id, :src_node, :dest_node, :relation, properties: %{}]

  @doc """
  Create a new Edge from a map.

  ## Example

      edge = Edge.new(%{
        src_node: john,
        dest_node: japan,
        relation: "visited"
      })
  """
  @spec new(map()) :: t()
  def new(map) do
    struct(__MODULE__, map)
  end

  @doc "Convert an edge's properties to a query-appropriate string."
  @spec properties_to_string(t()) :: String.t()
  def properties_to_string(edge) do
    inner =
      Map.keys(edge.properties)
      |> Enum.map(fn key -> "#{key}:#{Util.quote_string(edge.properties[key])}" end)
      |> Enum.join(",")

    if String.length(inner) > 0 do
      "{" <> inner <> "}"
    else
      ""
    end
  end

  @doc "Convert an edge to a query-appropriate string."
  @spec to_query_string(t()) :: String.t()
  def to_query_string(edge) do
    src_node_string = "(" <> edge.src_node.alias <> ")"

    edge_string =
      case edge.relation do
        "" -> "-[" <> properties_to_string(edge) <> "]->"
        nil -> "-[" <> properties_to_string(edge) <> "]->"
        other -> "-[:" <> other <> properties_to_string(edge) <> "]->"
      end

    dest_node_string = "(" <> edge.dest_node.alias <> ")"

    src_node_string <> edge_string <> dest_node_string
  end

  @doc """
  Compare two edges with respect to equality.

  Comparison logic:

  * If the ids differ, returns ``false``
  * If the source nodes differ, returns ``false``
  * If the destination nodes differ, returns ``false``
  * If the relations differ, returns ``false``
  * If the properties differ, returns ``false``
  * Otherwise returns true
  """
  @spec compare(t(), t()) :: boolean()
  def compare(left, right) do
    cond do
      left.id != right.id -> false
      left.src_node != right.src_node -> false
      left.dest_node != right.dest_node -> false
      left.relation != right.relation -> false
      map_size(left.properties) != map_size(right.properties) -> false
      not Map.equal?(left.properties, right.properties) -> false
      true -> true
    end
  end
end
