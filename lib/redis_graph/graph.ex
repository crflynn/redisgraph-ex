defmodule RedisGraph.Graph do
  @moduledoc """
  A Graph consisting of `RedisGraph.Node`s and `RedisGraph.Edge`s.

  A name is required for each graph.

  Construct graphs by adding `RedisGraph.Node`s followed
  by `RedisGraph.Edge`s which relate existing nodes.

  If a node does not have an alias, a random alias will
  be created for it when adding to a `RedisGraph.Graph`.

  Edges cannot be added unless both the source node and
  destination node aliases already exist in the graph.
  """
  alias RedisGraph.Edge
  alias RedisGraph.Node

  @type t() :: %__MODULE__{name: String.t()}

  @enforce_keys [:name]
  defstruct [:name]

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
  @spec new(%{name: String.t()}) :: t()
  def new(%{name: name} = map) when is_binary(name) do
    struct(__MODULE__, map)
  end
end
