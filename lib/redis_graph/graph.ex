defmodule RedisGraph.Graph do
  alias RedisGraph.Node

  require Logger

  @enforce_keys [:name]
  defstruct [
    :name,
    nodes: %{},
    edges: []
  ]

  def new(map) do
    struct(__MODULE__, map)
  end

  def add_node(graph, node) do
    node = Node.set_alias_if_nil(node)
    {%{graph | nodes: Map.put(graph.nodes, node.alias, node)}, node}
  end

  def add_edge(graph, edge) do
    cond do
      not node_in_graph?(graph, edge.src_node) -> {:error, "source node not in graph"}
      not node_in_graph?(graph, edge.dest_node) -> {:error, "destination node not in graph"}
      true -> {:ok, %{graph | edges: graph.edges ++ [edge]}}
    end
  end

  defp node_in_graph?(graph, node) do
    Map.has_key?(graph.nodes, node.alias)
  end
end
