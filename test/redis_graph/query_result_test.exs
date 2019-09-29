defmodule RedisGraph.QueryResultTest do
  alias RedisGraph.Edge
  alias RedisGraph.Graph
  alias RedisGraph.Node
  alias RedisGraph.QueryResult

  use ExUnit.Case

  @redis_address "redis://localhost:6379"

  test "functionality of query result parsing" do
    {:ok, conn} = Redix.start_link("redis://localhost:6379")

    sample_graph = RedisGraphTest.build_sample_graph()

    {:ok, commit_result} = RedisGraph.commit(conn, sample_graph)
    %QueryResult{} = commit_result

    query = "MATCH (p:person)-[v:visited]->(c:country) RETURN c.name, p, v"

    # Execute the query
    {:ok, query_result} = RedisGraph.query(conn, sample_graph.name, query)
  
    # Pretty print the results using the Scribe lib
    assert String.contains?(QueryResult.pretty_print(query_result), "c.name")

    {:ok, delete_result} = RedisGraph.delete(conn, sample_graph.name)
    assert is_binary(Map.get(delete_result.statistics, "Query internal execution time"))
  end

  test "query result properties" do
    {:ok, conn} = Redix.start_link("redis://localhost:6379")

    sample_graph = RedisGraphTest.build_sample_graph()

    {:ok, commit_result} = RedisGraph.commit(conn, sample_graph)
    %QueryResult{} = commit_result

    query = "MATCH (p:person)-[v:visited]->(c:country) RETURN c.name, p, v"

    # Execute the query
    {:ok, query_result} = RedisGraph.query(conn, sample_graph.name, query)

    assert is_nil(QueryResult.labels_added(query_result))
    assert is_nil(QueryResult.nodes_created(query_result))
    assert is_nil(QueryResult.nodes_deleted(query_result))
    assert is_nil(QueryResult.properties_set(query_result))
    assert is_nil(QueryResult.relationships_created(query_result))
    assert is_nil(QueryResult.relationships_deleted(query_result))
    assert is_binary(QueryResult.query_internal_execution_time(query_result))
  end
end