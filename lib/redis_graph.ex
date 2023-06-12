defmodule RedisGraph do
  @moduledoc """

  Query builder that provides functions
  to construct Cypher queries for for RedisGraph database
  and interact with the entities through defined structures.

  The library is developed on top of an existing [library](https://github.com/crflynn/redisgraph-ex)
  and provides additional functionality with refacted codebase to support
  [RedisGraph result set](https://redis.io/docs/stack/graph/design/client_spec/).

  To launch ``redisgraph`` locally with Docker, use

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
  # [
  #   [
  #     %RedisGraph.Node{
  #       id: 2,
  #       alias: :n,
  #       labels: ["Person"],
  #       properties: %{age: 30, name: "John Doe", works: true}
  #     },
  #     30,
  #     %RedisGraph.Node{
  #       id: 3,
  #       alias: :m,
  #       labels: ["Place"],
  #       properties: %{name: "Japan"}
  #     }
  #   ]
  # ]

  ```


  """

  alias RedisGraph.QueryResult
  alias RedisGraph.Util

  require Logger

  @type connection() :: GenServer.server()

  @doc """
  Execute arbitrary command against the database.

  https://oss.redislabs.com/redisgraph/commands/

  Query commands will be a list of strings. They
  will begin with either ``GRAPH.QUERY``,
  ``GRAPH.EXPLAIN``, or ``GRAPH.DELETE``.

  The next element will be the name of the graph.

  The third element will be the query command.

  Optionally pass the last element ``--compact``
  for compact results.

  ## Example:
      [
        "GRAPH.QUERY",
        "imdb",
        "MATCH (a:actor)-[:act]->(m:movie {title:'straight outta compton'})",
        "--compact"
      ]
  """
  @spec command(connection(), list(String.t())) ::
          {:ok, QueryResult.t()} | {:error, any()}
  def command(conn, c) do
    # Logger.debug(Enum.join(c, " "))

    case Redix.command(conn, c) do
      {:ok, result} ->
        {:ok, QueryResult.new(%{conn: conn, graph_name: Enum.at(c, 1), raw_result_set: result})}

      {:error, _reason} = error ->
        error
    end
  end

  @doc """
  Query on a graph in the database.

  Returns a `RedisGraph.QueryResult` containing the result set
  and metadata associated with the query.

  https://oss.redislabs.com/redisgraph/commands/#graphquery
  """
  @spec query(connection(), String.t(), String.t()) ::
          {:ok, QueryResult.t()} | {:error, any()}
  def query(conn, name, q) do
    c = ["GRAPH.QUERY", name, q, "--compact"]
    command(conn, c)
  end

  @doc """
  Fetch the execution plan for a query on a graph.

  Returns a raw result containing the query plan.

  https://redis.io/commands/graph.explain/
  """
  @spec execution_plan(connection(), String.t(), String.t()) ::
          {:ok, QueryResult.t()} | {:error, any()}
  def execution_plan(conn, name, q) do
    c = ["GRAPH.EXPLAIN", name, q]

    case Redix.command(conn, c) do
      {:error, _reason} = error ->
        error

      {:ok, result} ->
        # Logger.debug(result)
        {:ok, result}
    end
  end

  @doc """
  Delete a graph from the database.

  Returns a `RedisGraph.QueryResult` with statistic for
  query execution time.

  https://oss.redislabs.com/redisgraph/commands/#delete
  """
  @spec delete(connection(), String.t()) ::
          {:ok, QueryResult.t()} | {:error, any()}
  def delete(conn, name) do
    command = ["GRAPH.DELETE", name]
    RedisGraph.command(conn, command)
  end

  @doc """
  Execute a procedure call against the graph specified.

  Returns the raw result of the procedure call.

  https://oss.redislabs.com/redisgraph/commands/#procedures
  """
  @spec call_procedure(connection(), String.t(), String.t(), list(), map()) ::
          {:ok, list()} | {:error, any()}
  def call_procedure(conn, name, procedure, args \\ [], kwargs \\ %{}) do
    args = Enum.map_join(args, ",", &Util.value_to_string/1)

    yields = Map.get(kwargs, "y", [])

    yields =
      if length(yields) > 0 do
        " YIELD " <> Enum.join(yields, ",")
      else
        ""
      end

    q = "CALL " <> procedure <> "(" <> args <> ")" <> yields
    c = ["GRAPH.QUERY", name, q, "--compact"]

    case Redix.command(conn, c) do
      {:ok, result} ->
        {:ok, result}

      {:error, _reason} = error ->
        error
    end
  end

  @doc "Fetch the raw response of the ``db.labels()`` procedure call against the specified graph."
  @spec labels(connection(), String.t()) :: {:ok, list()} | {:error, any()}
  def labels(conn, name) do
    call_procedure(conn, name, "db.labels")
  end

  @doc "Fetch the raw response of the ``db.relationshipTypes()`` procedure call against the specified graph."
  @spec relationship_types(connection(), String.t()) :: {:ok, list()} | {:error, any()}
  def relationship_types(conn, name) do
    call_procedure(conn, name, "db.relationshipTypes")
  end

  @doc "Fetch the raw response of the ``db.propertyKeys()`` procedure call against the specified graph."
  @spec property_keys(connection(), String.t()) :: {:ok, list()} | {:error, any()}
  def property_keys(conn, name) do
    call_procedure(conn, name, "db.propertyKeys")
  end
end
