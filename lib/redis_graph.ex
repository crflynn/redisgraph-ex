defmodule RedisGraph do
  @moduledoc """
  Documentation for RedisGraph.

  Provides the components to construct and easily interact with Graph
  entities in a RedisGraph database.

  This library uses [Redix](https://github.com/whatyouhide/redix) to
  communicate with a redisgraph server.

  To launch ``redisgraph`` locally with Docker, use

  ```bash
  docker run -p 6379:6379 -it --rm redislabs/redisgraph
  ```

  Here is a simple example:

  ```elixir
  alias RedisGraph.{Node, Edge, Graph, QueryResult}

  # Create a connection using Redix
  {:ok, conn} = Redix.start_link("redis://localhost:6379")

  # Create a graph with the connection
  graph = Graph.new(%{
    name: "social",
    conn: conn
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

  # Commit the graph to the database
  {:ok, commit_result} = Graph.commit(graph)

  # Print the transaction statistics
  IO.inspect(commit_result.statistics)

  # Create a query to fetch some data
  query = "MATCH (p:person)-[v:visited]->(c:country) RETURN p.name, p.age, v.purpose, c.name"

  # Execute the query
  {:ok, query_result} = Graph.query(graph, query)

  # Pretty print the results using the Scribe lib
  IO.puts(QueryResult.pretty_print(query_result))
  ```

  which gives the following results:

  ```elixir
  # Commit result statistics
  %{
    "Labels added" => nil,
    "Nodes created" => "2",
    "Nodes deleted" => nil,
    "Properties set" => "5",
    "Query internal execution time" => "0.228669",
    "Relationships created" => "1",
    "Relationships deleted" => nil
  }

  # Query result pretty-printed
  +----------------+-------------+-----------------+--------------+
  | "p.name"       | "p.age"     | "v.purpose"     | "c.name"     |
  +----------------+-------------+-----------------+--------------+
  | "John Doe"     | 33          | nil             | "Japan"      |
  +----------------+-------------+-----------------+--------------+
  ```

  """
  alias RedisGraph.Node
  alias RedisGraph.Edge
  alias RedisGraph.Graph
  alias RedisGraph.QueryResult

  require Logger

  def command(conn, c) do
    Logger.debug(Enum.join(c, " "))

    case Redix.command(conn, c) do
      {:ok, result} ->
        {:ok, QueryResult.new(%{raw_result_set: result})}

      {:error, _reason} = error ->
        error
    end
  end

  def query(conn, name, q) do
    c = ["GRAPH.QUERY", name, q, "--compact"]
    command(conn, c)
  end

  def execution_plan(conn, name, q) do
    c = ["GRAPH.EXPLAIN", name, q]

    case Redix.command(conn, c) do
      {:error, _reason} = error ->
        error

      {:ok, result} ->
        Logger.debug(result)
        {:ok, result}
    end
  end

  def commit(conn, graph) do
    if length(graph.edges) == 0 and map_size(graph.nodes) == 0 do
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

      query_string = "MERGE " <> nodes_string <> "," <> edges_string

      query_string =
        if String.at(query_string, -1) == "," do
          String.slice(query_string, 0..-2)
        else
          query_string
        end

      RedisGraph.query(conn, graph.name, query_string)
    end
  end

  def delete(conn, name) do
    command = ["GRAPH.DELETE", name]
    RedisGraph.command(conn, command)
  end

  def merge(conn, name, pattern) do
    RedisGraph.query(conn, name, "MERGE " <> pattern)
  end

  def flush(conn, graph) do
    case RedisGraph.commit(conn, graph) do
      {:error, _reason} = error ->
        error

      {:ok, _result} ->
        {:ok, Graph.new(%{name: graph.name})}
    end
  end

  # def call_procedure(conn, name, procedure, args \\ [], kwargs \\ %{}) do
  #   args =
  #     args
  #     |> Enum.map(&Util.quote_string/1)
  #     |> Enum.join(",")

  #   yields = Map.get(kwargs, "y", [])

  #   yields =
  #   if length(yields) > 0 do
  #     " YIELD " <> Enum.join(yields, ",")
  #   else
  #     ""
  #   end

  #   q = "CALL " <> procedure <> "(" <> args <> ")" <> yields
  #   query(conn, name, q)
  # end

  # def labels(conn, name) do
  #   call_procedure(conn, name, "db.labels")
  # end

  # def relationship_types(conn, name) do
  #   call_procedure(conn, name, "db.relationshipTypes")
  # end

  # def property_keys(conn, name) do
  #   call_procedure(conn, name, "db.propertyKeys")
  # end
end
