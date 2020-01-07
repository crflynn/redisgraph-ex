defmodule RedisGraph.GraphTest do
  alias RedisGraph.Edge
  alias RedisGraph.Graph
  alias RedisGraph.Node

  use ExUnit.Case

  test "creates a new graph" do
    mygraph = Graph.new(%{name: "social"})

    assert %Graph{} = mygraph
  end

  test "adds a node to the graph" do
    {:ok, conn} = Redix.start_link("redis://localhost:6379")
    mygraph = Graph.new(%{conn: conn})

    mynode = Node.new(%{alias: "a", label: "person", properties: %{name: "John Doe"}})

    {mygraph, _} = Graph.add_node(mygraph, mynode)

    assert mynode == Map.get(mygraph.nodes, "a")
  end

  test "adds an edge to the graph" do
    {:ok, conn} = Redix.start_link("redis://localhost:6379")
    mygraph = Graph.new(%{conn: conn})

    src_node = Node.new(%{label: "person", properties: %{name: "John Doe"}})
    dest_node = Node.new(%{label: "place", properties: %{name: "Japan"}})

    {mygraph, src_node} = Graph.add_node(mygraph, src_node)
    {mygraph, dest_node} = Graph.add_node(mygraph, dest_node)

    myedge =
      Edge.new(%{src_node: src_node, dest_node: dest_node, properties: %{purpose: "pleasure"}})

    {:ok, mygraph} = Graph.add_edge(mygraph, myedge)

    assert Enum.at(mygraph.edges, 0) == myedge
  end
end
