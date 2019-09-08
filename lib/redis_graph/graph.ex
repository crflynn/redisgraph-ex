defmodule RedisGraph.Graph do
  alias RedisGraph.Node
  alias RedisGraph.Edge
  alias RedisGraph.Util
  alias RedisGraph.QueryResult

  require Logger

  @enforce_keys [:conn]
  defstruct [
    :name,
    :conn,
    nodes: %{},
    edges: [],
    labels: [],
    relationship_types: [],
    properties: []
  ]

  def new(map) do
    struct(__MODULE__, map)
  end

  def get_label(graph, idx) do
    graph = %{
      graph
      | labels:
          labels(graph)
          |> Enum.at(0)
    }

    Enum.at(graph.labels, idx)
  end

  def get_relation(graph, idx) do
    graph = %{
      graph
      | relationship_types:
          relationship_types(graph)
          |> Enum.at(0)
    }

    Enum.at(graph.relationship_types, idx)
  end

  def get_property(graph, idx) do
    graph = %{
      graph
      | properties:
          property_keys(graph)
          |> Enum.at(0)
    }

    Enum.at(graph.properties, idx)
  end

  def add_node(graph, node) do
    node = Node.set_alias_if_nil(node)
    {%{graph | nodes: Map.put(graph.nodes, node.alias, node)}, node}
  end

  def add_edge(graph, edge) do
    cond do
      !node_in_graph?(graph, edge.src_node) -> {:error, "source node not in graph"}
      !node_in_graph?(graph, edge.dest_node) -> {:error, "destination node not in graph"}
      true -> {:ok, %{graph | edges: graph.edges ++ [edge]}}
    end
  end

  defp node_in_graph?(graph, node) do
    Map.has_key?(graph.nodes, node.alias)
  end

  def commit(graph) do
    if length(graph.edges) == 0 && map_size(graph.nodes) == 0 do
      {:error, "graph is empty"}
    else
      nodes_string =
        graph.nodes
        |> Enum.map(fn {_label, node} -> Node.to_query_string(node) end)
        |> Enum.join(",")

      edges_string =
        graph.edges
        |> Enum.map(&Edge.to_query_string/1)
        |> Enum.join(",")

      query_string = "CREATE " <> nodes_string <> "," <> edges_string

      query_string =
        if String.at(query_string, -1) == "," do
          String.slice(query_string, 0..-2)
        else
          query_string
        end

      Logger.debug(query_string)

      {:ok, query(graph, query_string)}
    end
  end

  def flush(graph) do
    case commit(graph) do
      {:error, "graph is empty"} ->
        {:error, "graph is empty"}

      {:ok, _result} ->
        {:ok, %{graph | nodes: %{}, edges: []}}
    end
  end

  def query(graph, q) do
    Logger.debug(q)

    case Redix.command(graph.conn, ["GRAPH.QUERY", graph.name, q, "--compact"]) do
      {:ok, result} -> QueryResult.new(%{graph: graph, raw_result_set: result})
      {:error, result} -> result
    end
  end

  def execution_plan(graph, q) do
    Logger.debug(q)

    case Redix.command(graph.conn, ["GRAPH.EXPLAIN", graph.name, q]) do
      {:error, _} = error ->
        error

      {:ok, result} ->
        Logger.debug(result)
        {:ok, result}
    end
  end

  def delete(graph) do
    Redix.command(graph.conn, ["GRAPH.DELETE", graph.name])
  end

  def merge(graph, pattern) do
    query(graph, "MERGE " <> pattern)
  end

  def call_procedure(graph, procedure, args \\ [], kwargs \\ {}) do
    args =
      args
      |> Enum.map(&Util.quote_string/1)
      |> Enum.join(",")

    yields = Map.get(kwargs, "y", [])

    yields =
      if length(yields) > 0 do
        " YIELD " <> Enum.join(yields, ",")
      else
        ""
      end

    q = "CALL " <> procedure <> "(" <> args <> ")" <> yields
    query(graph, q)
  end

  def labels(graph) do
    call_procedure(graph, "db.labels").result_set
  end

  def relationship_types(graph) do
    call_procedure(graph, "db.relationshipTypes").result_set
  end

  def property_keys(graph) do
    call_procedure(graph, "db.propertyKeys").result_set
  end
end
