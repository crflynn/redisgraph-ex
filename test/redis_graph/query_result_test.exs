defmodule RedisGraph.QueryResultTest do
  alias RedisGraph.{QueryResult, Graph, Node, Relationship, Query}

  use ExUnit.Case, async: true

  @redis_address "redis://localhost:6379"

  setup_all do
    {atom, process_id} = Redix.start_link(@redis_address)
    graph = Graph.new(%{name: "test"})
    {atom, %{conn: process_id, graph: graph}}
  end

  setup context do
    on_exit(fn ->
      conn = context[:conn]
      graph = context[:graph]
      RedisGraph.delete(conn, graph.name)
    end)

    :ok
  end

  describe "Integration tests with hard-coded queries:" do
    test "test that result if an instance eof the QueryResult struct",
         %{conn: conn, graph: graph} = _context do
      query =
        "CREATE (n:Person {age: 10, hobbies: ['sports', 'cooking'], name: 'John'})-[r:HAS]->(m:Dog {age: 2, name: 'Charlie'}) RETURN n, r, m, m.age"

      {:ok, query_result} = RedisGraph.query(conn, graph.name, query)
      assert is_struct(query_result, QueryResult)
    end

    test "test that graph name returned is same as graph name provided",
         %{conn: conn, graph: graph} = _context do
      query =
        "CREATE (n:Person {age: 10, hobbies: ['sports', 'cooking'], name: 'John'})-[r:HAS]->(m:Dog {age: 2, name: 'Charlie'}) RETURN n, r, m, m.age"

      {:ok, query_result} = RedisGraph.query(conn, graph.name, query)
      graph_name = Map.get(query_result, :graph_name)
      assert graph_name == graph.name
    end

    test "test that number of elements in header is the same as requested",
         %{conn: conn, graph: graph} = _context do
      query =
        "CREATE (n:Person {age: 10, hobbies: ['sports', 'cooking'], name: 'John'})-[r:HAS]->(m:Dog {age: 2, name: 'Charlie'}) RETURN n, r, m, m.age"

      {:ok, query_result} = RedisGraph.query(conn, graph.name, query)
      header_length = Map.get(query_result, :header, []) |> length
      assert header_length == 4
    end

    test "test that number of elements in result_set is the same as requested",
         %{conn: conn, graph: graph} = _context do
      query =
        "CREATE (n:Person {age: 10, hobbies: ['sports', 'cooking'], name: 'John'})-[r:HAS]->(m:Dog {age: 2, name: 'Charlie'}) RETURN n, r, m, m.age"

      {:ok, query_result} = RedisGraph.query(conn, graph.name, query)
      result_set_length = Map.get(query_result, :result_set, []) |> List.first([]) |> length
      assert result_set_length == 4
    end

    test "test that statistics are correct", %{conn: conn, graph: graph} = _context do
      query =
        "CREATE (n:Person {age: 10, hobbies: ['sports', 'cooking'], name: 'John'})-[r:HAS]->(m:Dog {age: 2, name: 'Charlie'}) RETURN n, r, m, m.age"

      {:ok, query_result} = RedisGraph.query(conn, graph.name, query)
      assert not is_nil(QueryResult.labels_added(query_result))
      assert is_nil(QueryResult.labels_removed(query_result))
      assert not is_nil(QueryResult.nodes_created(query_result))
      assert is_nil(QueryResult.nodes_deleted(query_result))
      assert not is_nil(QueryResult.properties_set(query_result))
      assert is_nil(QueryResult.properties_removed(query_result))
      assert not is_nil(QueryResult.relationships_created(query_result))
      assert is_nil(QueryResult.relationships_deleted(query_result))
      assert is_nil(QueryResult.indices_created(query_result))
      assert is_nil(QueryResult.indices_deleted(query_result))
      assert not is_nil(QueryResult.query_internal_execution_time(query_result))
    end

    test "test that returned values are of correct data type",
         %{conn: conn, graph: graph} = _context do
      query =
        "CREATE (n:Person {age: 10, hobbies: ['sports', 'cooking'], name: 'John', stuff: null, money: 22.2, works: false})-[r:HAS {duration: 1}]->(m:Dog {age: 2, name: 'Charlie'}) RETURN n, r, m, n.age, n.hobbies, n.name, n.stuff, n.money, n.works, r.duration, m.name"

      {:ok, query_result} = RedisGraph.query(conn, graph.name, query)
      result_set = Map.get(query_result, :result_set, []) |> List.first([])
      # IO.puts("result_set")
      # IO.inspect(result_set)
      [n, r, m, n_age, n_hobbies, n_name, n_stuff, n_money, n_works, r_duration, m_name] =
        result_set

      assert is_struct(n, Node)
      assert is_struct(r, Relationship)
      assert is_struct(m, Node)
      assert is_number(n_age)
      assert is_list(n_hobbies)
      assert is_binary(n_name)
      assert is_nil(n_stuff)
      assert is_number(n_money)
      assert is_boolean(n_works)
      assert is_number(r_duration)
      assert is_binary(m_name)
    end

    test "test that returned values have correct values",
         %{conn: conn, graph: graph} = _context do
      query =
        "CREATE (n:Person {age: 10, hobbies: ['sports', 'cooking'], name: 'John', stuff: null, money: 22.2, works: false})-[r:HAS {duration: 1}]->(m:Dog {age: 2, name: 'Charlie'}) RETURN n, r, m, n.age, n.hobbies, n.name, n.stuff, n.money, n.works, r.duration, m.name"

      {:ok, query_result} = RedisGraph.query(conn, graph.name, query)
      result_set = Map.get(query_result, :result_set, []) |> List.first([])
      # IO.puts("result_set")
      # IO.inspect(result_set)
      [n, r, m, n_age, n_hobbies, n_name, n_stuff, n_money, n_works, r_duration, m_name] =
        result_set

      [
        n_correct,
        r_correct,
        m_correct,
        n_age_correct,
        n_hobbies_correct,
        n_name_correct,
        n_stuff_correct,
        n_money_correct,
        n_works_correct,
        r_duration_correct,
        m_name_correct
      ] = [
        %RedisGraph.Node{
          id: 0,
          alias: :n,
          labels: ["Person"],
          properties: %{
            age: 10,
            hobbies: ["sports", "cooking"],
            money: 22.2,
            name: "John",
            works: false
          }
        },
        %RedisGraph.Relationship{
          id: 0,
          alias: :r,
          src_node: 0,
          dest_node: 1,
          type: "HAS",
          properties: %{duration: 1}
        },
        %RedisGraph.Node{
          id: 1,
          alias: :m,
          labels: ["Dog"],
          properties: %{age: 2, name: "Charlie"}
        },
        10,
        ["sports", "cooking"],
        "John",
        nil,
        22.2,
        false,
        1,
        "Charlie"
      ]

      assert n == n_correct
      assert r == r_correct
      assert m == m_correct
      assert n_age == n_age_correct
      assert n_hobbies == n_hobbies_correct
      assert n_name == n_name_correct
      assert n_stuff == n_stuff_correct
      assert n_money == n_money_correct
      assert n_works == n_works_correct
      assert r_duration == r_duration_correct
      assert m_name == m_name_correct
    end

    test "test that query returns two sets of entities that match the condition",
         %{conn: conn, graph: graph} = _context do
      query =
        "CREATE (n:Person {age: 11, name: 'John'})-[r:HAS {duration: 1}]->(n:Dog {age: 2, name: 'Charlie'}), (n:Person {age: 22, name: 'Mike'})-[t:HAS {duration: 1}]->(m) " <>
          "WITH * MATCH (q)-[y {duration: 1}]->(w) RETURN q, y, w"

      {:ok, query_result} = RedisGraph.query(conn, graph.name, query)
      header = Map.get(query_result, :header, [])
      result_set = Map.get(query_result, :result_set, [])
      # IO.puts("query_result")
      # IO.inspect(query_result)
      assert length(header) == 3
      assert length(result_set) == 2
    end
  end

  describe "End-to-end testing using the query builder:" do
    test "create nodes with relatioships and test for multiple things",
         %{conn: conn, graph: graph} = _context do
      # same as "CREATE (n:Person {age: 10, hobbies: ['sports', 'cooking'], money: 22.2, name: 'John', stuff: null, works: false})-[r:HAS {duration: 1}]->(m:Dog {age: 2, name: 'Charlie'}) RETURN n, r, m, n.age, n.hobbies, n.name, n.stuff, n.money, n.works, r.duration, m.name"
      {:ok, query} =
        Query.new()
        |> Query.create()
        |> Query.node(:n, ["Person"], %{
          age: 10,
          hobbies: ["sports", "cooking"],
          name: "John",
          stuff: nil,
          money: 22.2,
          works: false
        })
        |> Query.relationship_from_to(:r, "HAS", %{duration: 1})
        |> Query.node(:m, ["Dog"], %{age: 2, name: "Charlie"})
        |> Query.return(:n)
        |> Query.return(:r)
        |> Query.return(:m)
        |> Query.return_property(:n, "age")
        |> Query.return_property(:n, "hobbies")
        |> Query.return_property(:n, "name")
        |> Query.return_property(:n, "stuff")
        |> Query.return_property(:n, "money")
        |> Query.return_property(:n, "works")
        |> Query.return_property(:r, "duration")
        |> Query.return_property(:m, "name")
        |> Query.build_query()

      {:ok, query_result} = RedisGraph.query(conn, graph.name, query)

      graph_name = Map.get(query_result, :graph_name)
      result_set = Map.get(query_result, :result_set, []) |> List.first([])

      [n, r, m, n_age, n_hobbies, n_name, n_stuff, n_money, n_works, r_duration, m_name] =
        result_set

      [
        n_correct,
        r_correct,
        m_correct,
        n_age_correct,
        n_hobbies_correct,
        n_name_correct,
        n_stuff_correct,
        n_money_correct,
        n_works_correct,
        r_duration_correct,
        m_name_correct
      ] = [
        %RedisGraph.Node{
          id: 0,
          alias: :n,
          labels: ["Person"],
          properties: %{
            age: 10,
            hobbies: ["sports", "cooking"],
            money: 22.2,
            name: "John",
            works: false
          }
        },
        %RedisGraph.Relationship{
          id: 0,
          alias: :r,
          src_node: 0,
          dest_node: 1,
          type: "HAS",
          properties: %{duration: 1}
        },
        %RedisGraph.Node{
          id: 1,
          alias: :m,
          labels: ["Dog"],
          properties: %{age: 2, name: "Charlie"}
        },
        10,
        ["sports", "cooking"],
        "John",
        nil,
        22.2,
        false,
        1,
        "Charlie"
      ]

      assert is_struct(query_result, QueryResult)
      assert graph_name == graph.name
      assert is_struct(n, Node)
      assert is_struct(r, Relationship)
      assert is_struct(m, Node)
      assert is_number(n_age)
      assert is_list(n_hobbies)
      assert is_binary(n_name)
      assert is_nil(n_stuff)
      assert is_number(n_money)
      assert is_boolean(n_works)
      assert is_number(r_duration)
      assert is_binary(m_name)
      assert n == n_correct
      assert r == r_correct
      assert m == m_correct
      assert n_age == n_age_correct
      assert n_hobbies == n_hobbies_correct
      assert n_name == n_name_correct
      assert n_stuff == n_stuff_correct
      assert n_money == n_money_correct
      assert n_works == n_works_correct
      assert r_duration == r_duration_correct
      assert m_name == m_name_correct
    end
  end

  test "create nodes with relatioships, then delete and lastly test for multiple things",
       %{conn: conn, graph: graph} = _context do
    # same as "CREATE (n:Person {age: 10, hobbies: ['sports', 'cooking'], money: 22.2, name: 'John', stuff: null, works: false})-[r:HAS {duration: 1}]->(m:Dog {age: 2, name: 'Charlie'}) RETURN n, r, m, n.age, n.hobbies, n.name, n.stuff, n.money, n.works, r.duration, m.name"
    {:ok, create_query} =
      Query.new()
      |> Query.create()
      |> Query.node(:n, ["Person"], %{
        age: 10,
        hobbies: ["sports", "cooking"],
        name: "John",
        stuff: nil,
        money: 22.2,
        works: false
      })
      |> Query.relationship_from_to(:r, "HAS", %{duration: 1})
      |> Query.node(:m, ["Dog"], %{age: 2, name: "Charlie"})
      |> Query.build_query()

    {:ok, _query_result} = RedisGraph.query(conn, graph.name, create_query)

    {:ok, delete_query} =
      Query.new()
      |> Query.match()
      |> Query.node(:n)
      |> Query.relationship_from_to(:r)
      |> Query.node(:m)
      |> Query.delete(:n)
      |> Query.delete(:r)
      |> Query.delete(:m)
      |> Query.build_query()

    {:ok, query_result} = RedisGraph.query(conn, graph.name, delete_query)

    assert is_nil(QueryResult.labels_added(query_result))
    assert is_nil(QueryResult.labels_removed(query_result))
    assert is_nil(QueryResult.nodes_created(query_result))
    assert not is_nil(QueryResult.nodes_deleted(query_result))
    assert is_nil(QueryResult.properties_set(query_result))
    assert is_nil(QueryResult.properties_removed(query_result))
    assert is_nil(QueryResult.relationships_created(query_result))
    assert not is_nil(QueryResult.relationships_deleted(query_result))
    assert is_nil(QueryResult.indices_created(query_result))
    assert is_nil(QueryResult.indices_deleted(query_result))
    assert not is_nil(QueryResult.query_internal_execution_time(query_result))
  end
end
