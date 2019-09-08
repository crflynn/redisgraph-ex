defmodule RedisGraph.Edge do
  alias RedisGraph.Util

  @enforce_keys [:src_node, :dest_node]
  defstruct [:id, :src_node, :dest_node, relation: "", properties: %{}]

  def new(map) do
    struct(__MODULE__, map)
  end

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

  def to_query_string(edge) do
    src_node_string = "(" <> edge.src_node.alias <> ")"

    edge_string =
      case edge.relation do
        "" -> "-[" <> properties_to_string(edge) <> "]->"
        other -> "-[:" <> other <> properties_to_string(edge) <> "]->"
      end

    dest_node_string = "(" <> edge.dest_node.alias <> ")"

    src_node_string <> edge_string <> dest_node_string
  end

  def left == right do
    cond do
      not is_nil(left.id) and not is_nil(right.id) and Kernel.==(left.id, right.id) -> true
      left.src_node != right.src_node -> false
      left.dest_node != right.dest_node -> false
      left.relation != right.relation -> false
      map_size(left.properties) != map_size(right.properties) -> false
      not Map.equal?(left.properties, right.properties) -> false
      true -> true
    end
  end
end
