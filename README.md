# RedisGraph

A [RedisGraph](https://oss.redislabs.com/redisgraph/) client implementation library in Elixir.

## Installation

The `redisgraph` package can be installed
by adding `redisgraph` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:redisgraph, "~> 0.1.0"}
  ]
end
```

Documentation can be found at [https://hexdocs.pm/redisgraph](https://hexdocs.pm/redisgraph).

## Example usage

This library uses [Redix](https://github.com/whatyouhide/redix) to communicate with a redisgraph server.

To launch ``redisgraph`` locally, use

```bash
docker run -p 6379:6379 -it --rm redislabs/redisgraph
```

Here is a simple example:

```elixir
alias RedisGraph.{Node, Edge, Graph, QueryResult}

# Create a connection using Redix
{:ok, conn} = Redix.start_link("redis://localhost:6379")

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

# Commit the graph to the database
{:ok, commit_result} = RedisGraph.commit(conn, graph)

# Print the transaction statistics
IO.inspect(commit_result.statistics)

# Create a query to fetch some data
query = "MATCH (p:person)-[v:visited]->(c:country) RETURN p.name, p.age, v.purpose, c.name"

# Execute the query
{:ok, query_result} = RedisGraph.query(conn, graph.name, query)

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

## License

RedisGraph is licensed under [MIT](https://github.com/crflynn/redisgraph-ex/blob/master/LICENSE.txt).