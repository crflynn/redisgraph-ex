defmodule RedisGraph.EdgeTest do
  alias RedisGraph.Node
  alias RedisGraph.Edge

  use ExUnit.Case

  test "creates a new Edge" do
    src_node = Node.new(%{label: "person", properties: %{name: "John Doe"}})
    dest_node = Node.new(%{label: "place", properties: %{name: "Japan"}})

    myedge =
      Edge.new(%{
        src_node: src_node,
        dest_node: dest_node,
        properties: %{purpose: "pleasure"}
      })

    assert %Edge{} = myedge
  end

  test "gets the properties to a string" do
    src_node = Node.new(%{label: "person", properties: %{name: "John Doe"}})
    dest_node = Node.new(%{label: "place", properties: %{name: "Japan"}})

    myedge =
      Edge.new(%{
        src_node: src_node,
        dest_node: dest_node,
        properties: %{purpose: "pleasure"}
      })

    props = Edge.properties_to_string(myedge)
    assert props == "{purpose:'pleasure'}"
  end

  test "gets the query string for the edge" do
    src_node = Node.new(%{alias: "p", label: "person", properties: %{name: "John Doe"}})
    dest_node = Node.new(%{alias: "j", label: "place", properties: %{name: "Japan"}})

    myedge =
      Edge.new(%{
        src_node: src_node,
        dest_node: dest_node,
        properties: %{purpose: "pleasure"}
      })

    query_string = Edge.to_query_string(myedge)
    assert query_string == "(p)-[{purpose:'pleasure'}]->(j)"

    myedge =
      Edge.new(%{
        src_node: src_node,
        dest_node: dest_node,
        relation: "",
        properties: %{purpose: "pleasure"}
      })

    query_string = Edge.to_query_string(myedge)
    assert query_string == "(p)-[{purpose:'pleasure'}]->(j)"

    myedge =
      Edge.new(%{
        src_node: src_node,
        dest_node: dest_node,
        relation: "vacation",
        properties: %{purpose: "pleasure"}
      })

    query_string = Edge.to_query_string(myedge)
    assert query_string == "(p)-[:vacation{purpose:'pleasure'}]->(j)"

    myedge =
      Edge.new(%{
        src_node: src_node,
        dest_node: dest_node,
        relation: "vacation"
      })

    query_string = Edge.to_query_string(myedge)
    assert query_string == "(p)-[:vacation]->(j)"
  end

  test "compares two edges correctly" do
    src_node = Node.new(%{label: "person", properties: %{name: "John Doe"}})
    dest_node = Node.new(%{label: "place", properties: %{name: "Japan"}})

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

    assert not Edge.compare(myedge, otheredge)

    # different source nodes
    other_node = Node.new(%{label: "food", properties: %{name: "Apple"}})

    myedge =
      Edge.new(%{
        src_node: src_node,
        dest_node: dest_node,
        properties: %{purpose: "pleasure"}
      })

    otheredge =
      Edge.new(%{
        src_node: other_node,
        dest_node: dest_node,
        properties: %{purpose: "pleasure"}
      })

    assert not Edge.compare(myedge, otheredge)

    # different destination nodes
    myedge =
      Edge.new(%{
        src_node: src_node,
        dest_node: dest_node,
        properties: %{purpose: "pleasure"}
      })

    otheredge =
      Edge.new(%{
        src_node: src_node,
        dest_node: other_node,
        properties: %{purpose: "pleasure"}
      })

    assert not Edge.compare(myedge, otheredge)

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

    assert not Edge.compare(myedge, otheredge)

    # different properties sizes
    myedge =
      Edge.new(%{
        src_node: src_node,
        dest_node: dest_node,
        properties: %{purpose: "pleasure"}
      })

    otheredge =
      Edge.new(%{
        src_node: src_node,
        dest_node: dest_node,
        properties: %{purpose: "pleasure", enjoyable: "very"}
      })

    assert not Edge.compare(myedge, otheredge)

    # different properties
    myedge =
      Edge.new(%{
        src_node: src_node,
        dest_node: dest_node,
        properties: %{purpose: "pleasure"}
      })

    otheredge =
      Edge.new(%{
        src_node: src_node,
        dest_node: dest_node,
        properties: %{purpose: "business"}
      })

    assert not Edge.compare(myedge, otheredge)

    # same edges
    myedge =
      Edge.new(%{
        src_node: src_node,
        dest_node: dest_node,
        properties: %{purpose: "pleasure"}
      })

    otheredge =
      Edge.new(%{
        src_node: src_node,
        dest_node: dest_node,
        properties: %{purpose: "pleasure"}
      })

    assert Edge.compare(myedge, otheredge)
  end
end
