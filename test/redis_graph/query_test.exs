defmodule RedisGraph.QueryTest do
  use ExUnit.Case, async: true
  alias RedisGraph.Query

  # :create! | :match! | :optional_match! | :merge! | :delete! | :set! | :on_match_set! | :on_create_set! | :with! | :where! | :order_by! | :limit! | :skip! | :return! | :return_distinct!

  describe "MATCH clause:" do
    test "build query that would match on a node (with alias n) and return it through the alias." do
      {:ok, query} =
        Query.new()
        |> Query.match()
        |> Query.node(:n)
        |> Query.return(:n)
        |> Query.build_query()

      assert query == "MATCH (n) RETURN n"
    end

    test "build query that would match on a node (with alias n, and label Person) and return it through the alias." do
      {:ok, query} =
        Query.new()
        |> Query.match()
        |> Query.node(:n, ["Person"])
        |> Query.return(:n)
        |> Query.build_query()

      assert query == "MATCH (n:Person) RETURN n"
    end

    test "build query that would match on a node (with alias n, and labels Person and Student) and return it through the alias." do
      {:ok, query} =
        Query.new()
        |> Query.match()
        |> Query.node(:n, ["Person", "Student"])
        |> Query.return(:n)
        |> Query.build_query()

      assert query == "MATCH (n:Person:Student) RETURN n"
    end

    test "build query that would match on a node (with alias n, and properties {age: 2, name: 'Mike'}) and return it through the alias." do
      {:ok, query} =
        Query.new()
        |> Query.match()
        |> Query.node(:n, %{age: 2, name: "Mike"})
        |> Query.return(:n)
        |> Query.build_query()

      assert query == "MATCH (n {age: 2, name: 'Mike'}) RETURN n"
    end

    test "build query that would match on a node (with alias n, label Person and properties {age: 2, name: 'Mike'}) and return it through the alias." do
      {:ok, query} =
        Query.new()
        |> Query.match()
        |> Query.node(:n, ["Person"], %{age: 2, name: "Mike"})
        |> Query.return(:n)
        |> Query.build_query()

      assert query == "MATCH (n:Person {age: 2, name: 'Mike'}) RETURN n"
    end

    test "build query that would match on a node (with alias n, and properties {age: 2, credit: null, has: ['dog', 11, 11.11, true, null], money: 22.22, name: 'Mike', young: true}) and return it through the alias." do
      {:ok, query} =
        Query.new()
        |> Query.match()
        |> Query.node(:n, ["Person"], %{
          age: 2,
          name: "Mike",
          young: true,
          money: 22.22,
          credit: nil,
          has: ["dog", 11, 11.11, true, nil]
        })
        |> Query.return(:n)
        |> Query.build_query()

      assert query ==
               "MATCH (n:Person {age: 2, credit: null, has: ['dog', 11, 11.11, true, null], money: 22.22, name: 'Mike', young: true}) RETURN n"
    end

    test "build query that would match on a 2 nodes (with alias n and m) and return the node with alias n." do
      {:ok, query} =
        Query.new()
        |> Query.match()
        |> Query.node(:n)
        |> Query.node(:m)
        |> Query.return(:n)
        |> Query.build_query()

      assert query == "MATCH (n),(m) RETURN n"
    end

    test "build query that would match on a 2 nodes (with alias n and label Person and m and properties {age: 2, name: 'Mike'}) and return the node with alias n." do
      {:ok, query} =
        Query.new()
        |> Query.match()
        |> Query.node(:n, ["Person"])
        |> Query.node(:m, %{age: 2, name: "Mike"})
        |> Query.return(:n)
        |> Query.build_query()

      assert query == "MATCH (n:Person),(m {age: 2, name: 'Mike'}) RETURN n"
    end

    test "build query that would match on a 3 nodes (with alias n and label Person, alias m and properties {age: 2, name: 'Mike'} and alias b) and return the node with alias n." do
      {:ok, query} =
        Query.new()
        |> Query.match()
        |> Query.node(:n, ["Person"])
        |> Query.node(:m, %{age: 2, name: "Mike"})
        |> Query.node(:b)
        |> Query.return(:n)
        |> Query.build_query()

      assert query == "MATCH (n:Person),(m {age: 2, name: 'Mike'}),(b) RETURN n"
    end

    test "build query that would match on a 2 nodes (with alias n and label Person and m and properties {age: 2, name: 'Mike'}) and return them through the aliases." do
      {:ok, query} =
        Query.new()
        |> Query.match()
        |> Query.node(:n, ["Person"])
        |> Query.node(:m, %{age: 2, name: "Mike"})
        |> Query.return(:n)
        |> Query.return(:m)
        |> Query.build_query()

      assert query == "MATCH (n:Person),(m {age: 2, name: 'Mike'}) RETURN n, m"
    end

    test "build query that would match on a 3 nodes (with alias n and label Person, alias m and properties {age: 2, name: 'Mike'} and alias b) and return them through the aliases." do
      {:ok, query} =
        Query.new()
        |> Query.match()
        |> Query.node(:n, ["Person"])
        |> Query.node(:m, %{age: 2, name: "Mike"})
        |> Query.node(:b)
        |> Query.return(:n)
        |> Query.return(:m)
        |> Query.return(:b)
        |> Query.build_query()

      assert query == "MATCH (n:Person),(m {age: 2, name: 'Mike'}),(b) RETURN n, m, b"
    end

    test "build query that would match on a node with alias n, relationship with alias r coming from the first one and going to second node with alias m and return them through the aliases." do
      {:ok, query} =
        Query.new()
        |> Query.match()
        |> Query.node(:n)
        |> Query.relationship_from_to(:r)
        |> Query.node(:m)
        |> Query.return(:n)
        |> Query.return(:r)
        |> Query.return(:m)
        |> Query.build_query()

      assert query == "MATCH (n)-[r]->(m) RETURN n, r, m"
    end

    test "build query that would match on a node with alias n, relationship (with alias r type Friend and properties coming from the first one and going to second node with alias m and return them through the aliases." do
      {:ok, query} =
        Query.new()
        |> Query.match()
        |> Query.node(:n)
        |> Query.relationship_from_to(:r, "Friend", %{
          bool: true,
          integer: 3,
          float: 12.12,
          str: "Hi",
          stuff: [5, 21.21, "String", false, nil],
          nothing: nil
        })
        |> Query.node(:m)
        |> Query.return(:n)
        |> Query.return(:r)
        |> Query.return(:m)
        |> Query.build_query()

      assert query ==
               "MATCH (n)-[r:Friend {bool: true, float: 12.12, integer: 3, nothing: null, str: 'Hi', stuff: [5, 21.21, 'String', false, null]}]->(m) RETURN n, r, m"
    end

    test "build query that would match on a node with alias n, relationship (with alias r type Friend coming from the first one and going to second node with alias m and a separate node b and return them through the aliases." do
      {:ok, query} =
        Query.new()
        |> Query.match()
        |> Query.node(:n)
        |> Query.relationship_from_to(:r, "Friend")
        |> Query.node(:m)
        |> Query.node(:b)
        |> Query.return(:n)
        |> Query.return(:r)
        |> Query.return(:m)
        |> Query.return(:b)
        |> Query.build_query()

      assert query == "MATCH (n)-[r:Friend]->(m),(b) RETURN n, r, m, b"
    end

    test "build query that would match on a node with alias n, relationship with alias r coming from the first one and going to second node m and another relationship t going from node m to node b and return them through the aliases." do
      {:ok, query} =
        Query.new()
        |> Query.match()
        |> Query.node(:n)
        |> Query.relationship_from_to(:r)
        |> Query.node(:m)
        |> Query.relationship_from_to(:t)
        |> Query.node(:b)
        |> Query.return(:n)
        |> Query.return(:r)
        |> Query.return(:m)
        |> Query.return(:t)
        |> Query.return(:b)
        |> Query.build_query()

      assert query == "MATCH (n)-[r]->(m)-[t]->(b) RETURN n, r, m, t, b"
    end

    test "build query that would match on a node with alias n, relationship with alias r going to first one and coming from second node with alias m and return them through the aliases." do
      {:ok, query} =
        Query.new()
        |> Query.match()
        |> Query.node(:n)
        |> Query.relationship_to_from(:r)
        |> Query.node(:m)
        |> Query.return(:n)
        |> Query.return(:r)
        |> Query.return(:m)
        |> Query.build_query()

      assert query == "MATCH (n)<-[r]-(m) RETURN n, r, m"
    end

    test "build query that would match on a node with alias n, relationship with alias r going to the first one and coming from second node m and another relationship t going to node m from node b and return them through the aliases." do
      {:ok, query} =
        Query.new()
        |> Query.match()
        |> Query.node(:n)
        |> Query.relationship_to_from(:r)
        |> Query.node(:m)
        |> Query.relationship_to_from(:t)
        |> Query.node(:b)
        |> Query.return(:n)
        |> Query.return(:r)
        |> Query.return(:m)
        |> Query.return(:t)
        |> Query.return(:b)
        |> Query.build_query()

      assert query == "MATCH (n)<-[r]-(m)<-[t]-(b) RETURN n, r, m, t, b"
    end

    test "build query that would match on a node n, relationship r coming from the first one and going to second node m and another relationship t coming to node m and going from node b and return them through the aliases." do
      {:ok, query} =
        Query.new()
        |> Query.match()
        |> Query.node(:n)
        |> Query.relationship_from_to(:r)
        |> Query.node(:m)
        |> Query.relationship_to_from(:t)
        |> Query.node(:b)
        |> Query.return(:n)
        |> Query.return(:r)
        |> Query.return(:m)
        |> Query.return(:t)
        |> Query.return(:b)
        |> Query.build_query()

      assert query == "MATCH (n)-[r]->(m)<-[t]-(b) RETURN n, r, m, t, b"
    end

    test "build query that would give error since node alias is provided as string instead of atom." do
      {:error, query} =
        Query.new()
        |> Query.match()
        |> Query.node("n")
        |> Query.return(:n)
        |> Query.build_query()

      assert query ==
               "Provided alias is not an atom, only atoms are accepted. E.g. new() |> match() |> node(:n) |> relationship_from_to(:r) |> node(:m) |> ..."
    end

    test "build query that would give error since node labels is provided not as list." do
      {:error, query} =
        Query.new()
        |> Query.match()
        |> Query.node(:n, "test")
        |> Query.return(:n)
        |> Query.build_query()

      assert query == "Wrong parameters provided to node(:n)"
    end

    test "build query that would give error since node labels is provided not as list and node parameters not as map." do
      {:error, query} =
        Query.new()
        |> Query.match()
        |> Query.node(:n, "test", "test2")
        |> Query.build_query()

      assert query == "Wrong parameters provided to node(:n)"
    end

    test "build query that would give error since not all node labels are strings." do
      {:error, query} =
        Query.new()
        |> Query.match()
        |> Query.node(:n, ["Person", 2, nil])
        |> Query.return(:n)
        |> Query.build_query()

      assert query == "Provided labels must all be of string type."
    end

    test "build query that would give error since relationship alias is not atom." do
      {:error, query} =
        Query.new()
        |> Query.match()
        |> Query.node(:n, ["Person"])
        |> Query.relationship_from_to("r")
        |> Query.node(:m)
        |> Query.return(:n)
        |> Query.build_query()

      assert query ==
               "Provided alias is not an atom, only atoms are accepted. E.g. new() |> match() |> node(:n) |> relationship_from_to(:r) |> node(:m) |> ..."
    end

    test "build query that would give error since relationship type is not string." do
      {:error, query} =
        Query.new()
        |> Query.match()
        |> Query.node(:n, ["Person"])
        |> Query.relationship_from_to(:r, ["Knows"])
        |> Query.node(:m)
        |> Query.build_query()

      assert query == "Wrong parameters provided to relationship_from_to(:r)"
    end

    test "build query that would give error since relationship type is not string and property is not map." do
      {:error, query} =
        Query.new()
        |> Query.match()
        |> Query.node(:n, ["Person"])
        |> Query.relationship_from_to(:r, ["Knows"], "property")
        |> Query.node(:m)
        |> Query.build_query()

      assert query == "Wrong parameters provided to relationship_from_to(:r)"
    end

    test "build query that would give error since relationship doesn't start from a node." do
      {:error, query} =
        Query.new()
        |> Query.match()
        |> Query.relationship_from_to(:r)
        |> Query.node(:m)
        |> Query.build_query()

      assert query ==
               "Relationship has to originate from a Node. Add a Node first with node() function"
    end

    test "build query that would give error since relationship doesn't point to a node." do
      {:error, query} =
        Query.new()
        |> Query.match()
        |> Query.node(:n, ["Person"])
        |> Query.relationship_from_to(:r)
        |> Query.build_query()

      assert query ==
               "MATCH clause cannot end with a Relationship, add a Node at the end. E.g. new() |> match() |> node(:n) |> relationship_from_to(:r) |> node(:m) |> ..."
    end

    test "build query that would give error since there are 2 relationships in a row." do
      {:error, query} =
        Query.new()
        |> Query.match()
        |> Query.node(:n, ["Person"])
        |> Query.relationship_from_to(:r)
        |> Query.relationship_from_to(:b)
        |> Query.node(:m)
        |> Query.build_query()

      assert query ==
               "You cannot have multiple Relationships in a row. Add a Node between them with node() function"
    end

    test "build query that would give error since reverse relationship alias is not atom." do
      {:error, query} =
        Query.new()
        |> Query.match()
        |> Query.node(:n, ["Person"])
        |> Query.relationship_to_from("r")
        |> Query.node(:m)
        |> Query.build_query()

      assert query ==
               "Provided alias is not an atom, only atoms are accepted. E.g. new() |> match() |> node(:n) |> relationship_from_to(:r) |> node(:m) |> ..."
    end

    test "build query that would give error since reverse relationship type is not string." do
      {:error, query} =
        Query.new()
        |> Query.match()
        |> Query.node(:n, ["Person"])
        |> Query.relationship_to_from(:r, ["Knows"])
        |> Query.node(:m)
        |> Query.build_query()

      assert query == "Wrong parameters provided to relationship_to_from(:r)"
    end

    test "build query that would give error since reverse relationship type is not string and property is not map." do
      {:error, query} =
        Query.new()
        |> Query.match()
        |> Query.node(:n, ["Person"])
        |> Query.relationship_to_from(:r, ["Knows"], "property")
        |> Query.node(:m)
        |> Query.build_query()

      assert query == "Wrong parameters provided to relationship_to_from(:r)"
    end

    test "build query that would give error since reverse relationship doesn't start from a node." do
      {:error, query} =
        Query.new()
        |> Query.match()
        |> Query.relationship_to_from(:r)
        |> Query.node(:m)
        |> Query.build_query()

      assert query == "Relationship has to point to a Node. Add a Node first with node() function"
    end

    test "build query that would give error since reverse relationship doesn't point to a node." do
      {:error, query} =
        Query.new()
        |> Query.match()
        |> Query.node(:n, ["Person"])
        |> Query.relationship_to_from(:r)
        |> Query.build_query()

      assert query ==
               "MATCH clause cannot end with a Relationship, add a Node at the end. E.g. new() |> match() |> node(:n) |> relationship_from_to(:r) |> node(:m) |> ..."
    end

    test "build query that would give error since there are 2 reverse relationships in a row." do
      {:error, query} =
        Query.new()
        |> Query.match()
        |> Query.node(:n, ["Person"])
        |> Query.relationship_to_from(:r)
        |> Query.relationship_to_from(:b)
        |> Query.node(:m)
        |> Query.build_query()

      assert query ==
               "You cannot have multiple Relationships in a row. Add a Node between them with node() function"
    end

    test "build query that would give error since context is wrong." do
      {:error, query} =
        Query.match(%{error: nil, test: "test"})
        |> Query.node(:n, ["Person", 2, nil])
        |> Query.build_query()

      assert query ==
               "Please instantiate the query first with new(). Istead have e.g. new() |> match |> node(:n) |> return(:n) |> build_query()"
    end

    # test "build query that would give error since same alias is provided for two different nodes." do
    #   {:error, query} =
    #     Query.new()
    #     |> Query.match()
    #     |> Query.node(:n, ["Person"])
    #     |> Query.node(:n)
    #     |> Query.build_query()

    #   assert query == "Provided alias: :n was alreay mentioned before. Pass the another alias: e.g. new() |> match() |> node(:n) |> node(:m) |> order_by_property(:n, \"age\") |> ..."
    # end

    # test "build query that would give error since same alias is provided for node and relationship." do
    #   {:error, query} =
    #     Query.new()
    #     |> Query.match()
    #     |> Query.node(:n, ["Person"])
    #     |> Query.relationship_from_to(:n)
    #     |> Query.node(:m)
    #     |> Query.build_query()

    #   assert query == "Provided alias: :n was alreay mentioned before." <>
    #   " Pass the another alias: e.g. new() |> match() |> node(:n) |> relationship_from_to(:r, \"WORKS\")  |> relationship_from_to(:t, \"KNOWS\") |> order_by_property(:n, \"age\") |> ..."
    # end

    # test "build query that would give error since same alias is provided for node and reverse relationship." do
    #   {:error, query} =
    #     Query.new()
    #     |> Query.match()
    #     |> Query.node(:n, ["Person"])
    #     |> Query.relationship_to_from(:n)
    #     |> Query.node(:m)
    #     |> Query.build_query()

    #   assert query == "Provided alias: :n was alreay mentioned before." <>
    #   " Pass the another alias: e.g. new() |> match() |> node(:n) |> relationship_to_from(:r, \"WORKS\")  |> relationship_to_from(:t, \"KNOWS\") |> order_by_property(:n, \"age\") |> ..."
    # end

    # test "build query that would give error since same alias is provided for two different relatioships." do
    #   {:error, query} =
    #     Query.new()
    #     |> Query.match()
    #     |> Query.node(:n, ["Person"])
    #     |> Query.relationship_from_to(:r)
    #     |> Query.node(:m)
    #     |> Query.relationship_to_from(:r)
    #     |> Query.node(:b)
    #     |> Query.build_query()

    #   assert query == "Provided alias: :r was alreay mentioned before." <>
    #   " Pass the another alias: e.g. new() |> match() |> node(:n) |> relationship_to_from(:r, \"WORKS\")  |> relationship_to_from(:t, \"KNOWS\") |> order_by_property(:n, \"age\") |> ..."
    # end

    # test "build query that would give error since same alias is provided for relationship and node." do
    #   {:error, query} =
    #     Query.new()
    #     |> Query.match()
    #     |> Query.node(:n, ["Person"])
    #     |> Query.relationship_from_to(:r)
    #     |> Query.node(:r)
    #     |> Query.build_query()

    #   assert query == "Provided alias: :r was alreay mentioned before. Pass the another alias: e.g. new() |> match() |> node(:n) |> node(:m) |> order_by_property(:n, \"age\") |> ..."
    # end
  end

  describe "OPTIONAL MATCH clause:" do
    test "build query that would optional match on a node (with alias n, label Person and properties {age: 2, name: 'Mike'}) and return it through the alias." do
      {:ok, query} =
        Query.new()
        |> Query.optional_match()
        |> Query.node(:n, ["Person"], %{age: 2, name: "Mike"})
        |> Query.return(:n)
        |> Query.build_query()

      assert query == "OPTIONAL MATCH (n:Person {age: 2, name: 'Mike'}) RETURN n"
    end

    test "build query that would optional match on a 2 nodes (with alias n and label Person and m and properties {age: 2, name: 'Mike'}) and return the node with alias n." do
      {:ok, query} =
        Query.new()
        |> Query.optional_match()
        |> Query.node(:n, ["Person"])
        |> Query.node(:m, %{age: 2, name: "Mike"})
        |> Query.return(:n)
        |> Query.build_query()

      assert query == "OPTIONAL MATCH (n:Person),(m {age: 2, name: 'Mike'}) RETURN n"
    end

    test "build query that would optional match on a 1 nodes (with alias n and label Person) and match on 2 nodes (with alias m and properties {age: 2, name: 'Mike'} and alias b) and return them through the aliases." do
      {:ok, query} =
        Query.new()
        |> Query.optional_match()
        |> Query.node(:n, ["Person"])
        |> Query.match()
        |> Query.node(:m, %{age: 2, name: "Mike"})
        |> Query.node(:b)
        |> Query.return(:n)
        |> Query.return(:m)
        |> Query.return(:b)
        |> Query.build_query()

      assert query ==
               "OPTIONAL MATCH (n:Person) MATCH (m {age: 2, name: 'Mike'}),(b) RETURN n, m, b"
    end

    test "build query that would optional match on a node with alias n, relationship with alias r coming from the first one and going to second node with alias m and return them through the aliases." do
      {:ok, query} =
        Query.new()
        |> Query.optional_match()
        |> Query.node(:n)
        |> Query.relationship_from_to(:r)
        |> Query.node(:m)
        |> Query.return(:n)
        |> Query.return(:r)
        |> Query.return(:m)
        |> Query.build_query()

      assert query == "OPTIONAL MATCH (n)-[r]->(m) RETURN n, r, m"
    end

    test "build query that would match on a node with alias n, relationship (with alias r type Friend coming from node n to node m and optional match on a separate node b with label Person and return them through the aliases." do
      {:ok, query} =
        Query.new()
        |> Query.match()
        |> Query.node(:n)
        |> Query.relationship_from_to(:r, "Friend")
        |> Query.node(:m)
        |> Query.optional_match()
        |> Query.node(:b, ["Person"])
        |> Query.return(:n)
        |> Query.return(:r)
        |> Query.return(:m)
        |> Query.return(:b)
        |> Query.build_query()

      assert query == "MATCH (n)-[r:Friend]->(m) OPTIONAL MATCH (b:Person) RETURN n, r, m, b"
    end

    test "build query that would give error since node alias is provided as string instead of atom on ." do
      {:error, query} =
        Query.new()
        |> Query.optional_match()
        |> Query.node("n")
        |> Query.return(:n)
        |> Query.build_query()

      assert query ==
               "Provided alias is not an atom, only atoms are accepted. E.g. new() |> match() |> node(:n) |> relationship_from_to(:r) |> node(:m) |> ..."
    end

    test "build query that would give error since node labels is provided not as list and node parameters not as map." do
      {:error, query} =
        Query.new()
        |> Query.optional_match()
        |> Query.node(:n, "test", "test2")
        |> Query.build_query()

      assert query == "Wrong parameters provided to node(:n)"
    end

    test "build query that would give error since reverse relationship type is not string and property is not map." do
      {:error, query} =
        Query.new()
        |> Query.optional_match()
        |> Query.node(:n, ["Person"])
        |> Query.relationship_to_from(:r, ["Knows"], "property")
        |> Query.node(:m)
        |> Query.build_query()

      assert query == "Wrong parameters provided to relationship_to_from(:r)"
    end
  end

  describe "CREATE clause:" do
    test "create node n with label Person and properties {age: 5, name: 'Mike', works: false}" do
      {:ok, query} =
        Query.new()
        |> Query.create()
        |> Query.node(:n, ["Person"], %{age: 5, name: "Mike", works: false})
        |> Query.build_query()

      assert query == "CREATE (n:Person {age: 5, name: 'Mike', works: false})"
    end

    test "create node n with label Person and properties {age: 5, name: 'Mike', works: false} and node m with label Person, Student, and return the nodes by alias" do
      {:ok, query} =
        Query.new()
        |> Query.create()
        |> Query.node(:n, ["Person"], %{age: 5, name: "Mike", works: false})
        |> Query.node(:m, ["Person", "Student"])
        |> Query.return(:n)
        |> Query.return(:m)
        |> Query.build_query()

      assert query ==
               "CREATE (n:Person {age: 5, name: 'Mike', works: false}),(m:Person:Student) RETURN n, m"
    end

    test "create node n with label Person and properties {age: 5, name: 'Mike', works: false} and relationship r of type KNOWS and node m with label Person, Student, and return them all by aliases" do
      {:ok, query} =
        Query.new()
        |> Query.create()
        |> Query.node(:n, ["Person"], %{age: 5, name: "Mike", works: false})
        |> Query.relationship_from_to(:r, "KNOWS")
        |> Query.node(:m, ["Person", "Student"])
        |> Query.return(:n)
        |> Query.return(:r)
        |> Query.return(:m)
        |> Query.build_query()

      assert query ==
               "CREATE (n:Person {age: 5, name: 'Mike', works: false})-[r:KNOWS]->(m:Person:Student) RETURN n, r, m"
    end

    test "build query that would match on node, create the same node and return it." do
      {:ok, query} =
        Query.new()
        |> Query.match()
        |> Query.node(:n, ["Person"])
        |> Query.create()
        |> Query.node(:n)
        |> Query.return(:n)
        |> Query.build_query()

      assert query == "MATCH (n) CREATE (n) RETURN n"
    end

    test "build query that would match on node with relationship and node; then create the same node and return it." do
      {:ok, query} =
        Query.new()
        |> Query.match()
        |> Query.node(:n, ["Person"])
        |> Query.relationship_from_to(:r, "KNOWS")
        |> Query.node(:m, ["Person"])
        |> Query.create()
        |> Query.node(:n)
        |> Query.return(:n)
        |> Query.build_query()

      assert query == "MATCH (n)-[r:KNOWS]->(m:Person) CREATE (n) RETURN n"
    end

    test "build query that would give error since node labels is provided not as list." do
      {:error, query} =
        Query.new()
        |> Query.create()
        |> Query.node(:b, "test")
        |> Query.build_query()

      assert query == "Wrong parameters provided to node(:b)"
    end

    test "build query that would give error since node labels is provided not as list and node parameters not as map." do
      {:error, query} =
        Query.new()
        |> Query.create()
        |> Query.node(:n, "test", "test2")
        |> Query.build_query()

      assert query == "Wrong parameters provided to node(:n)"
    end

    test "build query that would give error since not all node labels are strings." do
      {:error, query} =
        Query.new()
        |> Query.create()
        |> Query.node(:n, ["Person", 2, nil])
        |> Query.build_query()

      assert query == "Provided labels must all be of string type."
    end

    test "build query that would give error since context is wrong." do
      {:error, query} =
        Query.create(%{error: nil, test: "test"})
        |> Query.node(:n)
        |> Query.build_query()

      assert query ==
               "Please instantiate the query first with new(). Istead have e.g. new() |> match |> node(:n) |> return(:n) |> build_query()"
    end

    test "build query that would give error since reverse relationship type is not string and property is not map." do
      {:error, query} =
        Query.new()
        |> Query.create()
        |> Query.node(:n, ["Person"])
        |> Query.relationship_to_from(:r, ["Knows"], "property")
        |> Query.node(:m)
        |> Query.build_query()

      assert query == "Wrong parameters provided to relationship_to_from(:r)"
    end

    test "build query that would give error since relationship's type is not provided on its creation." do
      {:error, query} =
        Query.new()
        |> Query.create()
        |> Query.node(:n, ["Person"], %{age: 5, name: "Mike", works: false})
        |> Query.relationship_from_to(:r)
        |> Query.node(:m, ["Person", "Student"])
        |> Query.return(:n)
        |> Query.return(:r)
        |> Query.return(:m)
        |> Query.build_query()

      assert query ==
               "When you create a relationship, the type has to be provided. E.g. new() |> match() |> node(:n) |> relationship_from_to(:r, \"WORKS\") |> ..."
    end

    test "build query that would give error since reverse relationship's type is not provided on its creation." do
      {:error, query} =
        Query.new()
        |> Query.create()
        |> Query.node(:n, ["Person"], %{age: 5, name: "Mike", works: false})
        |> Query.relationship_to_from(:r)
        |> Query.node(:m, ["Person", "Student"])
        |> Query.return(:n)
        |> Query.return(:r)
        |> Query.return(:m)
        |> Query.build_query()

      assert query ==
               "When you create a relationship, the type has to be provided. E.g. new() |> match() |> node(:n) |> relationship_from_to(:r, \"WORKS\") |> ..."
    end
  end

  describe "MERGE clause:" do
    test "merge node n with label Person and properties {age: 5, name: 'Mike', works: false} and node m with label Person, Student, and return the nodes by alias" do
      {:ok, query} =
        Query.new()
        |> Query.merge()
        |> Query.node(:n, ["Person"], %{age: 5, name: "Mike", works: false})
        |> Query.node(:m, ["Person", "Student"])
        |> Query.return(:n)
        |> Query.return(:m)
        |> Query.build_query()

      assert query ==
               "MERGE (n:Person {age: 5, name: 'Mike', works: false}),(m:Person:Student) RETURN n, m"
    end

    test "merge node n with label Person and properties {age: 5, name: 'Mike', works: false} and relationship r of type KNOWS and node m with label Person, Student, and return them all by aliases" do
      {:ok, query} =
        Query.new()
        |> Query.merge()
        |> Query.node(:n, ["Person"], %{age: 5, name: "Mike", works: false})
        |> Query.relationship_from_to(:r, "KNOWS")
        |> Query.node(:m, ["Person", "Student"])
        |> Query.return(:n)
        |> Query.return(:r)
        |> Query.return(:m)
        |> Query.build_query()

      assert query ==
               "MERGE (n:Person {age: 5, name: 'Mike', works: false})-[r:KNOWS]->(m:Person:Student) RETURN n, r, m"
    end

    test "build query that would give error since node labels is provided not as list and node parameters not as map." do
      {:error, query} =
        Query.new()
        |> Query.merge()
        |> Query.node(:n, "test", "test2")
        |> Query.build_query()

      assert query == "Wrong parameters provided to node(:n)"
    end

    test "build query that would give error since reverse relationship type is not string and property is not map." do
      {:error, query} =
        Query.new()
        |> Query.merge()
        |> Query.node(:n, ["Person"])
        |> Query.relationship_to_from(:r, ["Knows"], "property")
        |> Query.node(:m)
        |> Query.build_query()

      assert query == "Wrong parameters provided to relationship_to_from(:r)"
    end

    test "build query that would give error since context is wrong." do
      {:error, query} =
        Query.merge(%{error: nil, test: "test"})
        |> Query.node(:n)
        |> Query.build_query()

      assert query ==
               "Please instantiate the query first with new(). Istead have e.g. new() |> match |> node(:n) |> return(:n) |> build_query()"
    end

    # test "build query that would match on node with relationship and node then create the same node and return it." do
    #   {:error, query} =
    #     Query.new()
    #     |> Query.match()
    #     |> Query.node(:n, ["Person"])
    #     |> Query.relationship_from_to(:r, "KNOWS")
    #     |> Query.node(:m, ["Person"])
    #     |> Query.create
    #     |> Query.node(:n)
    #     |> Query.node(:n)
    #     |> Query.return(:n)
    #     |> Query.build_query()

    #   assert query == "Provided alias: :n was alreay mentioned before. Pass the another alias: e.g. new() |> match() |> node(:n) |> node(:m) |> order_by_property(:n, \"age\") |> ..."
    # end
  end

  describe "WHERE clause:" do
    test "build query that would match on a node n where age property is bigger than 5 and return it through the alias." do
      {:ok, query} =
        Query.new()
        |> Query.match()
        |> Query.node(:n)
        |> Query.where(:n, "age", :bigger, 5)
        |> Query.return(:n)
        |> Query.build_query()

      assert query == "MATCH (n) WHERE n.age > 5 RETURN n"
    end

    test "build query that would match on a node n where age property is not bigger or equal than 5 and return it through the alias." do
      {:ok, query} =
        Query.new()
        |> Query.match()
        |> Query.node(:n)
        |> Query.where_not(:n, "age", :smaller_or_equal, 5)
        |> Query.return(:n)
        |> Query.build_query()

      assert query == "MATCH (n) WHERE NOT n.age <= 5 RETURN n"
    end

    test "build query that would match on a node n where age property is bigger than 5 and where name property not contains 'A' string and return it through the alias." do
      {:ok, query} =
        Query.new()
        |> Query.match()
        |> Query.node(:n)
        |> Query.where(:n, "age", :bigger, 5)
        |> Query.and_not_where(:n, "name", :contains, "A")
        |> Query.return(:n)
        |> Query.build_query()

      assert query == "MATCH (n) WHERE n.age > 5 AND NOT n.name CONTAINS 'A' RETURN n"
    end

    test "build query that would match on a node n where age property is bigger than 5 and where name property not contains 'A' string or where hobby property is present in list ['sports', 'cooking', 'reading'] and return it through the alias." do
      {:ok, query} =
        Query.new()
        |> Query.match()
        |> Query.node(:n)
        |> Query.where(:n, "age", :bigger, 5)
        |> Query.and_not_where(:n, "name", :contains, "A")
        |> Query.or_where(:n, "hobby", :in, ["sports", "cooking", "reading"])
        |> Query.return(:n)
        |> Query.build_query()

      assert query ==
               "MATCH (n) WHERE n.age > 5 AND NOT n.name CONTAINS 'A' OR n.hobby IN ['sports', 'cooking', 'reading'] RETURN n"
    end

    test "build query that would match on a node n and node m where age property of n is bigger than 5 or where balance property of m not null return nodes by the alias." do
      {:ok, query} =
        Query.new()
        |> Query.match()
        |> Query.node(:n)
        |> Query.node(:m)
        |> Query.where(:n, "age", :bigger, 5)
        |> Query.or_not_where(:m, "balance", :is, nil)
        |> Query.and_where(:m, "balance", :is_not, nil)
        |> Query.return(:n)
        |> Query.return(:m)
        |> Query.build_query()

      assert query ==
               "MATCH (n),(m) WHERE n.age > 5 OR NOT m.balance IS null AND m.balance IS NOT null RETURN n, m"
    end

    test "build query that would giver error because order of logical operators in where clause is wrong." do
      {:error, query} =
        Query.new()
        |> Query.match()
        |> Query.node(:n)
        |> Query.and_where(:n, "age", :bigger, 5)
        |> Query.where(:n, "age", :bigger, 5)
        |> Query.return(:n)
        |> Query.build_query()

      assert query ==
               "Provided order of WHERE clauses is wrong. You first call either where() or where_not() and then any number of the following or_where()/and_where()/or_not_where() etc. " <>
                 "E.g. new() |> match() |> node(:n) |> where(:n, \"age\", :bigger, 20) |> and_where(:n, \"name\", :contains, \"A\") |> return(:n) |> ..."
    end

    test "build query that would giver error because order of logical operators in where clause is wrong again." do
      {:error, query} =
        Query.new()
        |> Query.match()
        |> Query.node(:n)
        |> Query.where(:n, "age", :bigger, 5)
        |> Query.where(:n, "age", :bigger, 5)
        |> Query.return(:n)
        |> Query.build_query()

      assert query ==
               "Provided order of WHERE clauses is wrong. You first call either where() or where_not() and then any number of the following or_where()/and_where()/or_not_where() etc. " <>
                 "E.g. new() |> match() |> node(:n) |> where(:n, \"age\", :bigger, 20) |> and_where(:n, \"name\", :contains, \"A\") |> return(:n) |> ..."
    end

    test "build query that would giver error because node alias wasn't provided before." do
      {:error, query} =
        Query.new()
        |> Query.match()
        |> Query.node(:n)
        |> Query.where(:m, "age", :bigger, 5)
        |> Query.return(:n)
        |> Query.build_query()

      assert query ==
               "Provided alias: :m was not mentioned before. Pass the alias first: e.g. new() |> match() |> node(:n) |> order_by_property(:n, \"age\") |> ..."
    end

    test "build query that would giver error because property name wasn't provided." do
      {:error, query} =
        Query.new()
        |> Query.match()
        |> Query.node(:n)
        |> Query.where(:n, "", :bigger, 5)
        |> Query.return(:n)
        |> Query.build_query()

      assert query ==
               "Provide property name. E.g. new() |> match() |> node(:n) |> where(:n, \"age\", :bigger, 20}) |> return(:n) |> ..."
    end

    test "build query that would giver error because unsupported operator was provided." do
      {:error, query} =
        Query.new()
        |> Query.match()
        |> Query.node(:n)
        |> Query.where(:n, "age", :test, 5)
        |> Query.return(:n)
        |> Query.build_query()

      assert query ==
               "Provided value: 5 or/and operator: :test in the WHERE clause is not supported."
    end

    test "build query that would giver error because wrong operator was for the given value provided." do
      {:error, query} =
        Query.new()
        |> Query.match()
        |> Query.node(:n)
        |> Query.where(:n, "age", :in, 5)
        |> Query.return(:n)
        |> Query.build_query()

      assert query ==
               "Provided value: 5 or/and operator: :in in the WHERE clause is not supported."
    end

    test "build query that would giver error because wrong value is empty string." do
      {:error, query} =
        Query.new()
        |> Query.match()
        |> Query.node(:n)
        |> Query.where(:n, "age", :in, "")
        |> Query.return(:n)
        |> Query.build_query()

      assert query ==
               "Value can't be of empty string. E.g. new() |> match() |> node(:n) |> where({:n, \"age\", :contains, \"A\") |> return(:n) |> ..."
    end
  end

  describe "ORDER BY clause:" do
    test "build query that would match on a node n, return it through the alias and order by age property ascending." do
      {:ok, query} =
        Query.new()
        |> Query.match()
        |> Query.node(:n)
        |> Query.return(:n)
        |> Query.order_by(:n, "age")
        |> Query.build_query()

      assert query == "MATCH (n) RETURN n ORDER BY n.age ASC"
    end

    test "build query that would match on a node n, return it through the alias and order by age property ascending and name property descending." do
      {:ok, query} =
        Query.new()
        |> Query.match()
        |> Query.node(:n)
        |> Query.order_by(:n, "age")
        |> Query.order_by(:n, "name", false)
        |> Query.return(:n)
        |> Query.build_query()

      assert query == "MATCH (n) ORDER BY n.age ASC, n.name DESC RETURN n"
    end

    test "build query that would give error because provided alias is not metioned before." do
      {:error, query} =
        Query.new()
        |> Query.match()
        |> Query.node(:n)
        |> Query.return(:n)
        |> Query.order_by(:m, "age")
        |> Query.build_query()

      assert query ==
               "Provided alias: :m was not mentioned before. Pass the alias first: e.g. new() |> match() |> node(:n) |> order_by_property(:n, \"age\") |> ..."
    end

    test "build query that would give error because node property is of incorrect type." do
      {:error, query} =
        Query.new()
        |> Query.match()
        |> Query.node(:n)
        |> Query.return(:n)
        |> Query.order_by(:n, 5)
        |> Query.build_query()

      assert query ==
               "Wrong parameters provided. E.g. new() |> match() |> node(:n) |> order_by(:n, \"age\") |> return(:n) |> ..."
    end

    test "build query that would give error because node property is empty string." do
      {:error, query} =
        Query.new()
        |> Query.match()
        |> Query.node(:n)
        |> Query.return(:n)
        |> Query.order_by(:n, "")
        |> Query.build_query()

      assert query ==
               "Provide property name. E.g. new() |> match() |> node(:n) |> order_by(:n, \"age\") |> return(:n) |> ..."
    end

    test "build query that would give error because new() is not called." do
      {:error, query} =
        %{}
        |> Query.order_by(:n, "")
        |> Query.build_query()

      assert query ==
               "Please instantiate the query first with new(). Istead have e.g. new() |> match |> node(:n) |> return(:n) |> build_query()"
    end
  end

  describe "LIMIT clause:" do
    test "build query that would match on a node n, return it through the alias and limit output to 10 values." do
      {:ok, query} =
        Query.new()
        |> Query.match()
        |> Query.node(:n)
        |> Query.return(:n)
        |> Query.limit(10)
        |> Query.build_query()

      assert query == "MATCH (n) RETURN n LIMIT 10"
    end

    test "build query that would give error because match clause is not provided." do
      {:error, query} =
        Query.new()
        |> Query.limit(10)
        |> Query.build_query()

      assert query ==
               "MATCH or OPTIONAL MATCH or CREATE or MERGE clause has to be provided first before using LIMIT. E.g. new() |> match() |> node(:n) |> ..."
    end

    test "build query that would give error because incorrect value is provided." do
      {:error, query} =
        Query.new()
        |> Query.match()
        |> Query.node(:n)
        |> Query.return(:n)
        |> Query.limit("test")
        |> Query.build_query()

      assert query ==
               "Wrong number parameter was probided, only non negatibe integers supported. E.g. new() |> match() |> node(:n) |> return(:n) |> limit(10)|> build_query()"
    end
  end

  describe "SKIP clause:" do
    test "build query that would match on a node n, return it through the alias and skip 10 values." do
      {:ok, query} =
        Query.new()
        |> Query.match()
        |> Query.node(:n)
        |> Query.return(:n)
        |> Query.skip(10)
        |> Query.build_query()

      assert query == "MATCH (n) RETURN n SKIP 10"
    end

    test "build query that would give error because match clause is not provided." do
      {:error, query} =
        Query.new()
        |> Query.skip(10)
        |> Query.build_query()

      assert query ==
               "MATCH or OPTIONAL MATCH or CREATE or MERGE clause has to be provided first before using SKIP. E.g. new() |> match() |> node(:n) |> ..."
    end

    test "build query that would give error because incorrect value is provided." do
      {:error, query} =
        Query.new()
        |> Query.match()
        |> Query.node(:n)
        |> Query.return(:n)
        |> Query.skip("test")
        |> Query.build_query()

      assert query ==
               "Wrong number parameter was probided, only non negatibe integers supported. E.g. new() |> match() |> node(:n) |> return(:n) |> skip(10)|> build_query()"
    end
  end

  describe "WITH clause:" do
    test "build query that would match on a node n with n alias as person and return it through the alias person." do
      {:ok, query} =
        Query.new()
        |> Query.match()
        |> Query.node(:n)
        |> Query.with(:n, :person)
        |> Query.return(:person)
        |> Query.build_query()

      assert query == "MATCH (n) WITH n AS person RETURN person"
    end

    test "build query that would match on a node n with * and return it through the alias person." do
      {:ok, query} =
        Query.new()
        |> Query.match()
        |> Query.node(:n)
        |> Query.with(:*)
        |> Query.return(:n)
        |> Query.build_query()

      assert query == "MATCH (n) WITH * RETURN n"
    end

    test "build query that would match on a node n with property age alias as personAge and return it through the alias personAge." do
      {:ok, query} =
        Query.new()
        |> Query.match()
        |> Query.node(:n)
        |> Query.with_property(:n, "age", :personAge)
        |> Query.return(:personAge)
        |> Query.build_query()

      assert query == "MATCH (n) WITH n.age AS personAge RETURN personAge"
    end

    test "build query that would match on a node n with function labels() called on it and with alias as Labels and return it through the alias Labels." do
      {:ok, query} =
        Query.new()
        |> Query.match()
        |> Query.node(:n)
        |> Query.with_function("labels", :n, :Labels)
        |> Query.return(:Labels)
        |> Query.build_query()

      assert query == "MATCH (n) WITH labels(n) AS Labels RETURN Labels"
    end

    test "build query that would match on a node n with property name and function toUpper() on it called on it and with alias as Labels and return it through the alias Labels." do
      {:ok, query} =
        Query.new()
        |> Query.match()
        |> Query.node(:n)
        |> Query.with_function_and_property("toUpper", :n, "name", :Name)
        |> Query.return(:Name)
        |> Query.build_query()

      assert query == "MATCH (n) WITH toUpper(n.name) AS Name RETURN Name"
    end

    test "build query that would match on a node n with property name and function toUpper() on it called on it and with alias as Labels and another node m and return it through the alias Labels, m." do
      {:ok, query} =
        Query.new()
        |> Query.match()
        |> Query.node(:n)
        |> Query.node(:m)
        |> Query.with_function_and_property("toUpper", :n, "name", :Name)
        |> Query.with(:m)
        |> Query.return(:Name)
        |> Query.return(:m)
        |> Query.build_query()

      assert query == "MATCH (n),(m) WITH toUpper(n.name) AS Name, m RETURN Name, m"
    end

    test "build query that would give error because specified functions is empty string." do
      {:error, query} =
        Query.new()
        |> Query.match()
        |> Query.node(:m)
        |> Query.with_function("", :n, :Labels)
        |> Query.return(:Labels)
        |> Query.build_query()

      assert query ==
               "Provide function name. E.g. new() |> match() |> node(:n) |> with_function_and_property(\"toUpper\", :n, \"name\", :Name) |> return(:Name) |>..."
    end

    test "build query that would give error because specified property is empty string." do
      {:error, query} =
        Query.new()
        |> Query.match()
        |> Query.node(:m)
        |> Query.with_property(:n, "")
        |> Query.return(:n)
        |> Query.build_query()

      assert query ==
               "Provide property name. E.g. new() |> match() |> node(:n) |> with_function_and_property(\"toUpper\", :n, \"name\", :Name) |> return(:Name) |> ..."
    end

    test "build query that would give error because specified alias is not present." do
      {:error, query} =
        Query.new()
        |> Query.match()
        |> Query.node(:m)
        |> Query.with_function("labels", :n, :Labels)
        |> Query.return(:Labels)
        |> Query.build_query()

      assert query ==
               "Provided alias: :n was not mentioned before. Pass the alias first: e.g. new() |> match() |> node(:n) |> with(:n, :Node) |> |> return(:n) ..."
    end

    test "build query that would give error because specified alias in return is not present." do
      {:error, query} =
        Query.new()
        |> Query.match()
        |> Query.node(:m)
        |> Query.with_function("labels", :m, :Labels)
        |> Query.return(:LABELS)
        |> Query.build_query()

      assert query ==
               "Provided alias: :LABELS was not mentioned before. Pass the alias first: e.g. new() |> match() |> node(:n) |> order_by_property(:n, \"age\") |> ..."
    end

    test "build query that would give error because as variable is not an atom." do
      {:error, query} =
        Query.new()
        |> Query.match()
        |> Query.node(:m)
        |> Query.with_function("labels", :n, "Labels")
        |> Query.return(:Labels)
        |> Query.build_query()

      assert query ==
               "Provided as attribute: Labels needs to be an atom. E.g. new() |> match() |> node(:n) |> with(:n, :Node) |> |> return(:n) ..."
    end
  end

  describe "SET clause:" do
    test "build query that would match on a node n, set age property to 5 and return it through the alias." do
      {:ok, query} =
        Query.new()
        |> Query.match()
        |> Query.node(:n)
        |> Query.set_property(:n, "age", 5)
        |> Query.return(:n)
        |> Query.build_query()

      assert query == "MATCH (n) SET n.age = 5 RETURN n"
    end

    test "build query that would match on a node n, set name property to 'John' and return it through the alias." do
      {:ok, query} =
        Query.new()
        |> Query.match()
        |> Query.node(:n)
        |> Query.set_property(:n, "name", "John")
        |> Query.return(:n)
        |> Query.build_query()

      assert query == "MATCH (n) SET n.name = 'John' RETURN n"
    end

    test "build query that would match on a node n, set name property to uppercase 'john' and return it through the alias." do
      {:ok, query} =
        Query.new()
        |> Query.match()
        |> Query.node(:n)
        |> Query.set_property(:n, "name", "toUpper('john')")
        |> Query.return(:n)
        |> Query.build_query()

      assert query == "MATCH (n) SET n.name = toUpper('john') RETURN n"
    end

    test "build query that would match on a node n, set works property to false and hobby null, and return it through the alias." do
      {:ok, query} =
        Query.new()
        |> Query.match()
        |> Query.node(:n)
        |> Query.set_property(:n, "works", false)
        |> Query.set_property(:n, "hobby", nil)
        |> Query.return(:n)
        |> Query.build_query()

      assert query == "MATCH (n) SET n.works = false, n.hobby = null RETURN n"
    end

    test "build query that would match on a node n, set some properties and return it through the alias." do
      {:ok, query} =
        Query.new()
        |> Query.match()
        |> Query.node(:n)
        |> Query.set(:n, %{name: "Mike", age: 10, works: false})
        |> Query.return(:n)
        |> Query.build_query()

      assert query == "MATCH (n) SET n = {age: 10, name: 'Mike', works: false} RETURN n"
    end

    test "build query that would match on a node n, set/update some properties and return it through the alias." do
      {:ok, query} =
        Query.new()
        |> Query.match()
        |> Query.node(:n)
        |> Query.set(:n, %{name: "Mike", age: 10, works: false}, "+=")
        |> Query.return(:n)
        |> Query.build_query()

      assert query == "MATCH (n) SET n += {age: 10, name: 'Mike', works: false} RETURN n"
    end

    test "build query that would match on a node n, set to another node m and update stuff property for m, return them through the aliases." do
      {:ok, query} =
        Query.new()
        |> Query.match()
        |> Query.node(:n)
        |> Query.node(:m)
        |> Query.set(:n, :m)
        |> Query.set_property(:m, "stuff", ["Hi", 55, nil, false])
        |> Query.return(:n)
        |> Query.return(:m)
        |> Query.build_query()

      assert query == "MATCH (n),(m) SET n = m, m.stuff = ['Hi', 55, null, false] RETURN n, m"
    end

    test "build query that would give error because node m was not provided before." do
      {:error, query} =
        Query.new()
        |> Query.match()
        |> Query.node(:n)
        |> Query.set_property(:m, "age", 5)
        |> Query.return(:n)
        |> Query.build_query()

      assert query ==
               "Provided alias: :m was not mentioned before. Pass the alias first: e.g. new() |> match() |> node(:n) |> order_by_property(:n, \"age\") |> ..."
    end

    test "build query that would give error because property name is not provided." do
      {:error, query} =
        Query.new()
        |> Query.match()
        |> Query.node(:n)
        |> Query.set_property(:n, "", 5)
        |> Query.return(:n)
        |> Query.build_query()

      assert query ==
               "Provide property name. E.g. new() |> match() |> node(:n) |> set_property(:n, \"name\", :Name) |> return(:n) |> ..."
    end

    test "build query that would give error node n is set to node m which is not provided before." do
      {:error, query} =
        Query.new()
        |> Query.match()
        |> Query.node(:n)
        |> Query.set(:n, :m)
        |> Query.return(:n)
        |> Query.build_query()

      assert query ==
               "Provided alias: :m was not mentioned before. Pass the alias first: e.g. new() |> match() |> node(:n) |> order_by_property(:n, \"age\") |> ..."
    end

    test "build query that would give error as node n is set based on merge instead of match." do
      {:error, query} =
        Query.new()
        |> Query.merge()
        |> Query.node(:n)
        |> Query.set(:n, %{age: 5})
        |> Query.return(:n)
        |> Query.build_query()

      assert query ==
               "MATCH or OPTIONAL MATCH or CREATE clause has to be provided first before using SET. E.g. new() |> match() |> node(:n) |> ..."
    end

    test "build query that would give error as node n is set with wrong operator." do
      {:error, query} =
        Query.new()
        |> Query.match()
        |> Query.node(:n)
        |> Query.set(:n, %{age: 5}, "==")
        |> Query.return(:n)
        |> Query.build_query()

      assert query ==
               "Provided operator \"==\" is not supported. Only := (default) or :+= is supported. E.g. new() |> match() |> node(:n) |> node(:n) |> set_property(:n, \"age\", 100, :+=) |> ..."
    end
  end

  describe "ON MATCH SET clause:" do
    test "merge node n with label Person and properties {age: 5, name: 'Mike', works: false} and on match set update properties and return the node by alias" do
      {:ok, query} =
        Query.new()
        |> Query.merge()
        |> Query.node(:n, ["Person"], %{age: 5, name: "Mike", works: false})
        |> Query.on_match_set(
          :n,
          %{age: 50, name: "Michael", works: true, hobbies: ["sports", "cooking", "reading"]},
          "+="
        )
        |> Query.return(:n)
        |> Query.build_query()

      assert query ==
               "MERGE (n:Person {age: 5, name: 'Mike', works: false}) ON MATCH SET n += {age: 50, hobbies: ['sports', 'cooking', 'reading'], name: 'Michael', works: true} RETURN n"
    end

    test "merge node n with label Person and properties {age: 5, name: 'Mike', works: false} and on match set age to 50 and return the node by alias" do
      {:ok, query} =
        Query.new()
        |> Query.merge()
        |> Query.node(:n, ["Person"], %{age: 5, name: "Mike", works: false})
        |> Query.on_match_set_property(:n, "age", 50)
        |> Query.return(:n)
        |> Query.build_query()

      assert query ==
               "MERGE (n:Person {age: 5, name: 'Mike', works: false}) ON MATCH SET n.age = 50 RETURN n"
    end

    test "merge node n with label Person and properties {age: 5, name: 'Mike', works: false} and relationship r of type KNOWS and node m with label Person, Student, on match set node n and relationship r and return them all by aliases" do
      {:ok, query} =
        Query.new()
        |> Query.merge()
        |> Query.node(:n, ["Person"], %{age: 5, name: "Mike", works: false})
        |> Query.relationship_from_to(:r, "KNOWS")
        |> Query.node(:m, ["Person", "Student"])
        |> Query.on_match_set(
          :n,
          %{age: 50, name: "Michael", works: true, hobbies: ["sports", "cooking", "reading"]},
          "+="
        )
        |> Query.on_match_set(:r, %{duration: 5})
        |> Query.return(:n)
        |> Query.return(:r)
        |> Query.return(:m)
        |> Query.build_query()

      assert query ==
               "MERGE (n:Person {age: 5, name: 'Mike', works: false})-[r:KNOWS]->(m:Person:Student) ON MATCH SET n += {age: 50, hobbies: ['sports', 'cooking', 'reading'], name: 'Michael', works: true}, r = {duration: 5} RETURN n, r, m"
    end

    test "build query that would give error because node m was not provided before." do
      {:error, query} =
        Query.new()
        |> Query.merge()
        |> Query.node(:n)
        |> Query.on_match_set_property(:m, "age", 5)
        |> Query.return(:n)
        |> Query.build_query()

      assert query ==
               "Provided alias: :m was not mentioned before. Pass the alias first: e.g. new() |> match() |> node(:n) |> order_by_property(:n, \"age\") |> ..."
    end

    test "build query that would give error because property name is not provided." do
      {:error, query} =
        Query.new()
        |> Query.merge()
        |> Query.node(:n)
        |> Query.on_match_set_property(:n, "", 5)
        |> Query.return(:n)
        |> Query.build_query()

      assert query ==
               "Provide property name. E.g. new() |> match() |> node(:n) |> set_property(:n, \"name\", :Name) |> return(:n) |> ..."
    end

    test "build query that would give error node n is set to node m which is not provided before." do
      {:error, query} =
        Query.new()
        |> Query.merge()
        |> Query.node(:n)
        |> Query.on_match_set(:n, :m)
        |> Query.return(:n)
        |> Query.build_query()

      assert query ==
               "Provided alias: :m was not mentioned before. Pass the alias first: e.g. new() |> match() |> node(:n) |> order_by_property(:n, \"age\") |> ..."
    end

    test "build query that would give error as node n is set with match instead of merge." do
      {:error, query} =
        Query.new()
        |> Query.match()
        |> Query.node(:n)
        |> Query.on_match_set(:n, %{age: 5})
        |> Query.return(:n)
        |> Query.build_query()

      assert query ==
               "MERGE clause has to be provided first before using ON MATCH SET. E.g. new() |> merge() |> node(:n) |> node(:m) |> on_create_set(:n, \"m\") |> return(:n) |> ..."
    end

    test "build query that would give error as node n is set with wrong operator." do
      {:error, query} =
        Query.new()
        |> Query.merge()
        |> Query.node(:n)
        |> Query.on_match_set(:n, %{age: 5}, "==")
        |> Query.return(:n)
        |> Query.build_query()

      assert query ==
               "Provided operator \"==\" is not supported. Only := (default) or :+= is supported. E.g. new() |> match() |> node(:n) |> node(:n) |> set_property(:n, \"age\", 100, :+=) |> ..."
    end
  end

  describe "ON CREATE SET clause:" do
    test "merge node n with label Person and properties {age: 5, name: 'Mike', works: false} and on match set update properties and return the node by alias" do
      {:ok, query} =
        Query.new()
        |> Query.merge()
        |> Query.node(:n, ["Person"], %{age: 25, name: "Mike", works: true})
        |> Query.on_create_set(:n, %{hobbies: ["sports", "cooking", "reading"], stuff: nil}, "+=")
        |> Query.return(:n)
        |> Query.build_query()

      assert query ==
               "MERGE (n:Person {age: 25, name: 'Mike', works: true}) ON CREATE SET n += {hobbies: ['sports', 'cooking', 'reading'], stuff: null} RETURN n"
    end

    test "merge node n with label Person and properties {age: 5, name: 'Mike', works: false} and on create set hobbies property to a list of hobbies and return the node by alias" do
      {:ok, query} =
        Query.new()
        |> Query.merge()
        |> Query.node(:n, ["Person"], %{age: 5, name: "Mike", works: false})
        |> Query.on_create_set_property(:n, "hobbies", ["sports", "cooking", "reading"])
        |> Query.return(:n)
        |> Query.build_query()

      assert query ==
               "MERGE (n:Person {age: 5, name: 'Mike', works: false}) ON CREATE SET n.hobbies = ['sports', 'cooking', 'reading'] RETURN n"
    end

    test "merge node n with label Person and properties {age: 5, name: 'Mike', works: false} and relationship r of type KNOWS and node m with label Person, Student, set on create node n and relationship r and return them all by aliases" do
      {:ok, query} =
        Query.new()
        |> Query.merge()
        |> Query.node(:n, ["Person"], %{age: 5, name: "Mike", works: false})
        |> Query.relationship_from_to(:r, "KNOWS")
        |> Query.node(:m, ["Person", "Student"])
        |> Query.on_create_set(
          :n,
          %{age: 50, name: "Michael", works: true, hobbies: ["sports", "cooking", "reading"]},
          "+="
        )
        |> Query.on_create_set_property(:r, "duration", 5)
        |> Query.return(:n)
        |> Query.return(:r)
        |> Query.return(:m)
        |> Query.build_query()

      assert query ==
               "MERGE (n:Person {age: 5, name: 'Mike', works: false})-[r:KNOWS]->(m:Person:Student) ON CREATE SET n += {age: 50, hobbies: ['sports', 'cooking', 'reading'], name: 'Michael', works: true}, r.duration = 5 RETURN n, r, m"
    end

    test "merge node n with label Person and some properties and relationship r of type KNOWS and node m with label Person, Student, on create set node n and relationship r and on match set node m, and return them all by aliases" do
      {:ok, query} =
        Query.new()
        |> Query.merge()
        |> Query.node(:n, ["Person"], %{age: 5, name: "Mike", works: false})
        |> Query.relationship_from_to(:r, "KNOWS")
        |> Query.node(:m, ["Person", "Student"], %{name: "Bob"})
        |> Query.on_create_set(
          :n,
          %{age: 50, name: "Michael", works: true, hobbies: ["sports", "cooking", "reading"]},
          "+="
        )
        |> Query.on_create_set_property(:r, "duration", 5)
        |> Query.on_match_set_property(:m, "age", 25)
        |> Query.return(:n)
        |> Query.return(:r)
        |> Query.return(:m)
        |> Query.build_query()

      assert query ==
               "MERGE (n:Person {age: 5, name: 'Mike', works: false})-[r:KNOWS]->(m:Person:Student {name: 'Bob'}) ON CREATE SET n += {age: 50, hobbies: ['sports', 'cooking', 'reading'], name: 'Michael', works: true}, r.duration = 5 ON MATCH SET m.age = 25 RETURN n, r, m"
    end

    test "build query that would give error because node m was not provided before." do
      {:error, query} =
        Query.new()
        |> Query.merge()
        |> Query.node(:n)
        |> Query.on_create_set_property(:m, "age", 5)
        |> Query.return(:n)
        |> Query.build_query()

      assert query ==
               "Provided alias: :m was not mentioned before. Pass the alias first: e.g. new() |> match() |> node(:n) |> order_by_property(:n, \"age\") |> ..."
    end

    test "build query that would give error because property name is not provided." do
      {:error, query} =
        Query.new()
        |> Query.merge()
        |> Query.node(:n)
        |> Query.on_create_set_property(:n, "", 5)
        |> Query.return(:n)
        |> Query.build_query()

      assert query ==
               "Provide property name. E.g. new() |> match() |> node(:n) |> set_property(:n, \"name\", :Name) |> return(:n) |> ..."
    end

    test "build query that would give error node n is set to node m which is not provided before." do
      {:error, query} =
        Query.new()
        |> Query.merge()
        |> Query.node(:n)
        |> Query.on_create_set(:n, :m)
        |> Query.return(:n)
        |> Query.build_query()

      assert query ==
               "Provided alias: :m was not mentioned before. Pass the alias first: e.g. new() |> match() |> node(:n) |> order_by_property(:n, \"age\") |> ..."
    end

    test "build query that would give error as node n is set with match instead of merge." do
      {:error, query} =
        Query.new()
        |> Query.match()
        |> Query.node(:n)
        |> Query.on_create_set(:n, %{age: 5})
        |> Query.return(:n)
        |> Query.build_query()

      assert query ==
               "MERGE clause has to be provided first before using ON CREATE SET. E.g. new() |> merge() |> node(:n) |> node(:m) |> on_create_set(:n, \"m\") |> return(:n) |> ..."
    end

    test "build query that would give error as node n is set with wrong operator." do
      {:error, query} =
        Query.new()
        |> Query.merge()
        |> Query.node(:n)
        |> Query.on_create_set(:n, %{age: 5}, "==")
        |> Query.return(:n)
        |> Query.build_query()

      assert query ==
               "Provided operator \"==\" is not supported. Only := (default) or :+= is supported. E.g. new() |> match() |> node(:n) |> node(:n) |> set_property(:n, \"age\", 100, :+=) |> ..."
    end
  end

  describe "DELETE clause:" do
    test "build query that would match on a node n and delete it on alias." do
      {:ok, query} =
        Query.new()
        |> Query.match()
        |> Query.node(:n)
        |> Query.delete(:n)
        |> Query.build_query()

      assert query == "MATCH (n) DELETE n"
    end

    test "build query that would match on a node n and m, and delete them on aliases." do
      {:ok, query} =
        Query.new()
        |> Query.match()
        |> Query.node(:n)
        |> Query.node(:m)
        |> Query.delete(:n)
        |> Query.delete(:m)
        |> Query.build_query()

      assert query == "MATCH (n),(m) DELETE n, m"
    end

    test "build query that would match on a node n, relationahip r, node m, and separate node b with label Person and delete relationship r and node b." do
      {:ok, query} =
        Query.new()
        |> Query.match()
        |> Query.node(:n)
        |> Query.relationship_from_to(:r)
        |> Query.node(:m)
        |> Query.node(:b, ["Person"])
        |> Query.delete(:r)
        |> Query.delete(:b)
        |> Query.build_query()

      assert query == "MATCH (n)-[r]->(m),(b:Person) DELETE r, b"
    end

    test "build query that would give error because node m was not provided." do
      {:error, query} =
        Query.new()
        |> Query.match()
        |> Query.node(:n)
        |> Query.delete(:m)
        |> Query.build_query()

      assert query ==
               "Provided alias: :m was not mentioned before. Pass the alias first: e.g. new() |> match() |> node(:n) |> order_by_property(:n, \"age\") |> ..."
    end

    test "build query that would give error because context was not provided with new()" do
      {:error, query} =
        Query.delete(%{error: nil}, :m)
        |> Query.build_query()

      assert query ==
               "Please instantiate the query first with new(). Istead have e.g. new() |> match |> node(:n) |> return(:n) |> build_query()"
    end

    test "build query that would give error because delete() is not called." do
      {:error, query} =
        Query.new()
        |> Query.match()
        |> Query.node(:n)
        |> Query.build_query()

      assert query ==
               "In case you provide MATCH, OPTIONAL MATCH - then RETURN, RETURN DISCTINCT or DELETE also has to be provided. E.g. new() |> match |> node(:n) |> return(:n)"
    end
  end

  describe "RETURN clause:" do
    test "build query that would match on a node n and return it on alias." do
      {:ok, query} =
        Query.new()
        |> Query.match()
        |> Query.node(:n)
        |> Query.return(:n)
        |> Query.build_query()

      assert query == "MATCH (n) RETURN n"
    end

    test "build query that would match on a node n with label Person and return it as Person." do
      {:ok, query} =
        Query.new()
        |> Query.match()
        |> Query.node(:n, ["Person"])
        |> Query.return(:n, :Person)
        |> Query.build_query()

      assert query == "MATCH (n:Person) RETURN n AS Person"
    end

    test "build query that would match on a node n, relationship r and node m, and return n with property age, r with function type and node m function on property name." do
      {:ok, query} =
        Query.new()
        |> Query.match()
        |> Query.node(:n)
        |> Query.relationship_from_to(:r)
        |> Query.node(:m)
        |> Query.return_property(:n, "age")
        |> Query.return_function("type", :r)
        |> Query.return_function_and_property("toUpper", :m, "name")
        |> Query.build_query()

      assert query == "MATCH (n)-[r]->(m) RETURN n.age, type(r), toUpper(m.name)"
    end

    test "build query that would match on a node n, relationship r and node m, and return n with property age as Age, r with function type as Type and node m function on property name as Name." do
      {:ok, query} =
        Query.new()
        |> Query.match()
        |> Query.node(:n)
        |> Query.relationship_from_to(:r)
        |> Query.node(:m)
        |> Query.return_property(:n, "age", :Age)
        |> Query.return_function("type", :r, :Type)
        |> Query.return_function_and_property("toUpper", :m, "name", :Name)
        |> Query.build_query()

      assert query ==
               "MATCH (n)-[r]->(m) RETURN n.age AS Age, type(r) AS Type, toUpper(m.name) AS Name"
    end

    test "build query that would give error because provided alias is not present." do
      {:error, query} =
        Query.new()
        |> Query.match()
        |> Query.node(:n)
        |> Query.return(:m)
        |> Query.build_query()

      assert query ==
               "Provided alias: :m was not mentioned before. Pass the alias first: e.g. new() |> match() |> node(:n) |> order_by_property(:n, \"age\") |> ..."
    end

    test "build query that would give error because necessary clause for not provided first." do
      {:error, query} =
        Query.return(%{error: nil}, :m)
        |> Query.build_query()

      assert query ==
               "One of these clauses MATCH, CREATE, MERGE etc. has to be provided first before using RETURN. E.g. new() |> match() |> node(:n) |> return(:n)  |> ..."
    end

    test "build query that would give error because context is not provided through new() function context was not provided through new() function test." do
      {:error, query} =
        Query.match(%{error: nil})
        |> Query.return(:m)
        |> Query.build_query()

      assert query ==
               "Please instantiate the query first with new(). Istead have e.g. new() |> match |> node(:n) |> return(:n) |> build_query()"
    end

    test "build query that would give error because property name is not provided." do
      {:error, query} =
        Query.new()
        |> Query.match()
        |> Query.node(:n)
        |> Query.return_property(:n, "")
        |> Query.build_query()

      assert query ==
               "Provide property name. E.g. new() |> match() |> node(:n) |> return_property(:n, \"age\") |> ..."
    end

    test "build query that would give error because function name is not provided." do
      {:error, query} =
        Query.new()
        |> Query.match()
        |> Query.node(:n)
        |> Query.return_function("", :n, "name")
        |> Query.build_query()

      assert query ==
               "Provide function name. E.g. new() |> match() |> node(:n) |> return_function(\"toUpper\", :n) |> ..."
    end

    test "build query that would give error because return is not called." do
      {:error, query} =
        Query.new()
        |> Query.match()
        |> Query.node(:n)
        |> Query.build_query()

      assert query ==
               "In case you provide MATCH, OPTIONAL MATCH - then RETURN, RETURN DISCTINCT or DELETE also has to be provided. E.g. new() |> match |> node(:n) |> return(:n)"
    end

    test "build query that would give error because as varible is not atom." do
      {:error, query} =
        Query.new()
        |> Query.match()
        |> Query.node(:n, ["Person"])
        |> Query.return(:n, "Person")
        |> Query.build_query()

      assert query ==
               "Provided as attribute: Person needs to be an atom. E.g. Query.new() |> Query.match() |> Query.node(:n) |> Query.return(:n, :Node) |> Query.build_query()"
    end
  end

  describe "RETURN DISTINCT clause:" do
    test "build query that would match on a node n and return distinct it on alias." do
      {:ok, query} =
        Query.new()
        |> Query.match()
        |> Query.node(:n)
        |> Query.return_distinct(:n)
        |> Query.build_query()

      assert query == "MATCH (n) RETURN DISTINCT n"
    end

    test "build query that would match on a node n, relationship r and node m, and return distinct n with property age, r with function type and node m function on property name." do
      {:ok, query} =
        Query.new()
        |> Query.match()
        |> Query.node(:n)
        |> Query.relationship_from_to(:r)
        |> Query.node(:m)
        |> Query.return_distinct_property(:n, "age")
        |> Query.return_distinct_function("type", :r)
        |> Query.return_distinct_function_and_property("toUpper", :m, :name)
        |> Query.build_query()

      assert query == "MATCH (n)-[r]->(m) RETURN DISTINCT n.age, type(r), toUpper(m.name)"
    end

    test "build query that would match on a node n, relationship r and node m, and return distinct n with property age as Age, r with function type as Type and node m function on property name as Name." do
      {:ok, query} =
        Query.new()
        |> Query.match()
        |> Query.node(:n)
        |> Query.relationship_from_to(:r)
        |> Query.node(:m)
        |> Query.return_distinct_property(:n, "age", :Age)
        |> Query.return_distinct_function("type", :r, :Type)
        |> Query.return_distinct_function_and_property("toUpper", :m, "name", :Name)
        |> Query.build_query()

      assert query ==
               "MATCH (n)-[r]->(m) RETURN DISTINCT n.age AS Age, type(r) AS Type, toUpper(m.name) AS Name"
    end

    test "build query that would give error because provided alias is not present." do
      {:error, query} =
        Query.new()
        |> Query.match()
        |> Query.node(:n)
        |> Query.return_distinct(:m)
        |> Query.build_query()

      assert query ==
               "Provided alias: :m was not mentioned before. Pass the alias first: e.g. new() |> match() |> node(:n) |> order_by_property(:n, \"age\") |> ..."
    end

    test "build query that would give error context was not provided through new() function." do
      {:error, query} =
        Query.match(%{error: nil})
        |> Query.return_distinct(:m)
        |> Query.build_query()

      assert query ==
               "Please instantiate the query first with new(). Istead have e.g. new() |> match |> node(:n) |> return(:n) |> build_query()"
    end

    test "build query that would give error because as varible is not atom." do
      {:error, query} =
        Query.new()
        |> Query.match()
        |> Query.node(:n, ["Person"])
        |> Query.return_distinct(:n, "Person")
        |> Query.build_query()

      assert query ==
               "Provided as attribute: Person needs to be an atom. E.g. Query.new() |> Query.match() |> Query.node(:n) |> Query.return(:n, :Node) |> Query.build_query()"
    end

    test "build query that would give error because return_distinct() is not called." do
      {:error, query} =
        Query.new()
        |> Query.match()
        |> Query.node(:n)
        |> Query.build_query()

      assert query ==
               "In case you provide MATCH, OPTIONAL MATCH - then RETURN, RETURN DISCTINCT or DELETE also has to be provided. E.g. new() |> match |> node(:n) |> return(:n)"
    end
  end
end
