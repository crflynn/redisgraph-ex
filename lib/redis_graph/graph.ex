defmodule RedisGraph.Graph do
  @moduledoc """
  A Graph consisting of `RedisGraph.Nodes` and `RedisGraph.Edges`.

  A name is required for each graph.

  Construct graphs by adding `RedisGraph.Nodes` followed
  by `RedisGraph.Edges` which relate existing nodes.

  If a node does not have an alias, a random alias will
  be created for it prior to adding to a `RedisGraph.Graph`.

  Edges cannot be added unless both the source node and
  destination node aliases already exist in the graph.
  """
  alias RedisGraph.Edge
  alias RedisGraph.Node

  @type t() :: %__MODULE__{
          name: String.t(),
          nodes: %{optional(String.t()) => Node.t()},
          edges: list(Edge.t())
        }

  @enforce_keys [:name]
  defstruct [
    :name,
    nodes: %{},
    edges: []
  ]

  @doc """
  Create a graph from a map.

  ## Example
  ```
  alias RedisGraph.{Node, Edge, Graph, QueryResult}

  # Create a graph
  graph = Graph.new(%{
    name: "social"
  })

  # Create a node
  john = Node.new(%{
    label: "person",
    properties: %{
      name: "John Doe",
      age: 33,
      gender: "male",
      status: "single"
    }
  })

  # Add the node to the graph
  # The graph and node are returned
  # The node may be modified if no alias has been set
  # For this reason, nodes should always be added to the graph
  # before creating edges between them.
  {graph, john} = Graph.add_node(graph, john)

  # Create a second node
  japan = Node.new(%{
    label: "country",
    properties: %{
      name: "Japan"
    }
  })

  # Add the second node
  {graph, japan} = Graph.add_node(graph, japan)

  # Create an edge connecting the two nodes
  edge = Edge.new(%{
    src_node: john,
    dest_node: japan,
    relation: "visited"
  })

  # Add the edge to the graph
  # If the nodes are not present, an {:error, error} is returned
  {:ok, graph} = Graph.add_edge(graph, edge)
  ```
  """
  @spec new(map()) :: t()
  def new(map) do
    struct(__MODULE__, map)
  end

  @doc """
  Add a `RedisGraph.Node` to a graph.

  Creates a random string alias for the Node
  if the Node has no alias.
  """
  @spec add_node(t(), Node.t()) :: {t(), Node.t()}
  def add_node(graph, node) do
    node = Node.set_alias_if_nil(node)
    {%{graph | nodes: Map.put(graph.nodes, node.alias, node)}, node}
  end

  @doc """
  Add a `RedisGraph.Edge` to a graph.

  If the source node or destination node are not part of the
  graph, then the edge cannot be added. Uses node aliases
  to check graph membership.
  """
  @spec add_edge(t(), Edge.t()) :: {:ok, t()} | {:error, any()}
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
