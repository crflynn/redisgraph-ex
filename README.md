# RedisGraph


A [RedisGraph](https://redis.io/docs/stack/graph/) client implementation library in Elixir with support for Cypther query builing.


## Example usage

This library uses [Redix](https://github.com/whatyouhide/redix) to communicate with a redisgraph server.

To launch ``redisgraph`` locally, use

```bash
  docker run -p 6379:6379 -it --rm redis/redis-stack-server
```


Here is a simple example:

```elixir
 alias RedisGraph.{Query, Graph, QueryResult}

  # Create a connection using Redix
  {:ok, conn} = Redix.start_link("redis://localhost:6379")

  # Create a graph
  graph = Graph.new(%{
    name: "social"
  })

  {:ok, query} =
        Query.new()
        |> Query.create()
        |> Query.node(:n, ["Person"], %{age: 30, name: "John Doe", works: true})
        |> Query.relationship_from_to(:r, "TRAVELS_TO", %{purpose: "pleasure"})
        |> Query.node(:m, ["Place"], %{name: "Japan"})
        |> Query.return(:n)
        |> Query.return_property(:n, "age", :Age)
        |> Query.return(:m)
        |> Query.build_query()

  # query will hold
  # "MATCH "MATCH (n:Person {age: 30, name: 'John Doe', works: true})-[r:TRAVELS_TO {purpose: 'pleasure'}]->(m:Place {name: 'Japan'}) RETURN n, n.age AS Age, m"

  # Execute the query
  {:ok, query_result} = RedisGraph.query(conn, graph.name, query)

  # Get result set
  result_set = Map.get(query_result, :result_set)
  # result_set will hold
   <!-- 
   [
     [
       %RedisGraph.Node{
         id: 2,
         alias: :n,
         labels: ["Person"],
         properties: %{age: 30, name: "John Doe", works: true}
       },
       30,
       %RedisGraph.Node{
         id: 3,
         alias: :m,
         labels: ["Place"],
         properties: %{name: "Japan"}
       }
     ]
   ] -->
```

## License

RedisGraph is licensed under [MIT](https://github.com/crflynn/redisgraph-ex/blob/master/LICENSE.txt).