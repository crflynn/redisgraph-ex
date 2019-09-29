defmodule RedisGraph.GraphTest do
  alias RedisGraph.Graph
  alias RedisGraph.Edge
  alias RedisGraph.Node
  alias RedisGraph.QueryResult

  use ExUnit.Case

  test "creates a new graph" do
    {:ok, conn} = Redix.start_link("redis://localhost:6379")
    mygraph = Graph.new(%{conn: conn})

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

  # test "commits a graph" do
  #   {:ok, conn} = Redix.start_link("redis://localhost:6379")
  #   mygraph = Graph.new(%{conn: conn})

  #   src_node = Node.new(%{alias: "p", label: "person", properties: %{name: "John Doe"}})
  #   dest_node = Node.new(%{alias: "j", label: "place", properties: %{name: "Japan"}})

  #   {mygraph, src_node} = Graph.add_node(mygraph, src_node)
  #   {mygraph, dest_node} = Graph.add_node(mygraph, dest_node)

  #   myedge =
  #     Edge.new(%{
  #       relation: "trip",
  #       src_node: src_node,
  #       dest_node: dest_node,
  #       properties: %{purpose: "pleasure"}
  #     })

  #   {:ok, mygraph} = Graph.add_edge(mygraph, myedge)

  #   {:ok, %QueryResult{statistics: stats}} = Graph.commit(mygraph)

  #   # ensure the objects were created
  #   assert Map.get(stats, "Nodes created") == "2"
  #   assert Map.get(stats, "Relationships created") == "1"
  # end

  # test "generates an execution plan" do
  #   {:ok, conn} = Redix.start_link("redis://localhost:6379")
  #   mygraph = Graph.new(%{conn: conn})

  #   src_node = Node.new(%{alias: "p", label: "person", properties: %{name: "John Doe"}})
  #   dest_node = Node.new(%{alias: "j", label: "place", properties: %{name: "Japan"}})

  #   {mygraph, src_node} = Graph.add_node(mygraph, src_node)
  #   {mygraph, dest_node} = Graph.add_node(mygraph, dest_node)

  #   myedge =
  #     Edge.new(%{
  #       relation: "trip",
  #       src_node: src_node,
  #       dest_node: dest_node,
  #       properties: %{purpose: "pleasure"}
  #     })

  #   {:ok, mygraph} = Graph.add_edge(mygraph, myedge)

  #   {:ok, %QueryResult{graph: mygraph}} = Graph.commit(mygraph)

  #   q = "MATCH (p:person)-[]->(j:place {purpose:\"pleasure\"}) RETURN p"
  #   {:ok, plan} = Graph.execution_plan(mygraph, q)

  #   assert plan ==
  #            "Results\n    Project\n        Conditional Traverse\n            Filter\n                Node By Label Scan\n"
  # end
end
