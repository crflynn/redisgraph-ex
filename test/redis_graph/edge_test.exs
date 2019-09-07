defmodule RedisGraph.EdgeTest do
  alias RedisGraph.Node
  alias RedisGraph.Edge

  use ExUnit.Case

  test "creates a new Edge" do
    src_node = Node.new(%{alias: "person", properties: %{name: "John Doe"}})
    dest_node = Node.new(%{alias: "place", properties: %{name: "Japan"}})

    myedge =
      Edge.new(%{src_node: src_node, dest_node: dest_node, properties: %{purpose: "pleasure"}})

    assert %Edge{} = myedge
  end

  test "gets the properties to a string" do
    src_node = Node.new(%{alias: "person", properties: %{name: "John Doe"}})
    dest_node = Node.new(%{alias: "place", properties: %{name: "Japan"}})

    myedge =
      Edge.new(%{src_node: src_node, dest_node: dest_node, properties: %{purpose: "pleasure"}})

    props = Edge.properties_to_string(myedge)
    assert props == "{purpose:\"pleasure\"}"
  end

  test "gets the query string for the edge" do
    src_node = Node.new(%{alias: "person", properties: %{name: "John Doe"}})
    dest_node = Node.new(%{alias: "place", properties: %{name: "Japan"}})

    myedge =
      Edge.new(%{src_node: src_node, dest_node: dest_node, properties: %{purpose: "pleasure"}})

    query_string = Edge.to_query_string(myedge)
    assert query_string == "(person)-[:{purpose:\"pleasure\"}]->(place)"
  end

  test "compares two edges correctly" do
    src_node = Node.new(%{alias: "person", properties: %{name: "John Doe"}})
    dest_node = Node.new(%{alias: "place", properties: %{name: "Japan"}})

    # different ids
    myedge =
      Edge.new(%{
        id: "a",
        src_node: src_node,
        dest_node: dest_node,
        properties: %{purpose: "pleasure"}
      })

    otheredge =
      Edge.new(%{
        id: "b",
        src_node: src_node,
        dest_node: dest_node,
        properties: %{purpose: "pleasure"}
      })

    assert myedge != otheredge

    # different source nodes
    other_node = Node.new(%{alias: "food", properties: %{name: "Apple"}})

    myedge =
      Edge.new(%{src_node: src_node, dest_node: dest_node, properties: %{purpose: "pleasure"}})

    otheredge =
      Edge.new(%{src_node: other_node, dest_node: dest_node, properties: %{purpose: "pleasure"}})

    assert myedge != otheredge

    # different destination nodes
    myedge =
      Edge.new(%{src_node: src_node, dest_node: dest_node, properties: %{purpose: "pleasure"}})

    otheredge =
      Edge.new(%{src_node: src_node, dest_node: other_node, properties: %{purpose: "pleasure"}})

    assert myedge != otheredge

    # different relations
    myedge =
      Edge.new(%{
        src_node: src_node,
        relation: "a",
        dest_node: dest_node,
        properties: %{purpose: "pleasure"}
      })

    otheredge =
      Edge.new(%{
        src_node: src_node,
        relation: "b",
        dest_node: dest_node,
        properties: %{purpose: "pleasure"}
      })

    assert myedge != otheredge

    # different properties sizes
    myedge =
      Edge.new(%{src_node: src_node, dest_node: dest_node, properties: %{purpose: "pleasure"}})

    otheredge =
      Edge.new(%{
        src_node: src_node,
        dest_node: dest_node,
        properties: %{purpose: "pleasure", enjoyable: "very"}
      })

    assert myedge != otheredge

    # different properties
    myedge =
      Edge.new(%{src_node: src_node, dest_node: dest_node, properties: %{purpose: "pleasure"}})

    otheredge =
      Edge.new(%{src_node: src_node, dest_node: dest_node, properties: %{purpose: "business"}})

    assert myedge != otheredge

    # same edges
    myedge =
      Edge.new(%{src_node: src_node, dest_node: dest_node, properties: %{purpose: "pleasure"}})

    otheredge =
      Edge.new(%{src_node: src_node, dest_node: dest_node, properties: %{purpose: "pleasure"}})

    assert myedge == otheredge
  end
end
