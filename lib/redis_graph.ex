defmodule RedisGraph do
  alias RedisGraph.Relationship
  alias RedisGraph.Graph
  alias RedisGraph.Node
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
    args =
      args
      |> Enum.map(&Util.value_to_string/1)
      |> Enum.join(",")

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
