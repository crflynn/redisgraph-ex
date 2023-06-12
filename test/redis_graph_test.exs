# defmodule RedisGraphTest do
#   alias RedisGraph.Relationship
#   alias RedisGraph.Graph
#   alias RedisGraph.Node
#   alias RedisGraph.QueryResult

#   use ExUnit.Case

#   @redis_address "redis://localhost:6379"

#   def build_sample_graph() do
#     graph =
#       Graph.new(%{
#         name: "social"
#       })

#     john =
#       Node.new(%{
#         label: "person",
#         properties: %{
#           name: "John Doe",
#           age: 33,
#           gender: "male",
#           status: "single"
#         }
#       })

#     {graph, john} = Graph.add_node(graph, john)

#     japan =
#       Node.new(%{
#         label: "country",
#         properties: %{
#           name: "Japan"
#         }
#       })

#     {graph, japan} = Graph.add_node(graph, japan)

#     relationship =
#       Relationship.new(%{
#         src_node: john,
#         dest_node: japan,
#         relation: "visited"
#       })

#     {:ok, graph} = Graph.add_relationship(graph, relationship)
#     graph
#   end

#   test "commits a graph to the database" do
#     {:ok, conn} = Redix.start_link(@redis_address)

#     sample_graph = build_sample_graph()

#     {:ok, commit_result} = RedisGraph.commit(conn, sample_graph)
#     %QueryResult{} = commit_result

#     assert Map.get(commit_result.statistics, "Nodes created") == "2"
#     assert Map.get(commit_result.statistics, "Relationships created") == "1"

#     # cleanup
#     {:ok, delete_result} = RedisGraph.delete(conn, sample_graph.name)
#     assert is_binary(Map.get(delete_result.statistics, "Query internal execution time"))
#   end

#   test "creates an execution plan" do
#     {:ok, conn} = Redix.start_link(@redis_address)

#     sample_graph = build_sample_graph()

#     {:ok, commit_result} = RedisGraph.commit(conn, sample_graph)
#     %QueryResult{} = commit_result

#     assert Map.get(commit_result.statistics, "Nodes created") == "2"
#     assert Map.get(commit_result.statistics, "Relationships created") == "1"

#     q = "MATCH (p:person)-[]->(j:place {purpose:\"pleasure\"}) RETURN p"
#     {:ok, plan} = RedisGraph.execution_plan(conn, sample_graph.name, q)

#     assert plan ==
#              [
#                "Results",
#                "    Project",
#                "        Conditional Traverse | (j:place)->(p:person)",
#                "            Filter",
#                "                Node By Label Scan | (j:place)"
#              ]

#     # cleanup
#     {:ok, delete_result} = RedisGraph.delete(conn, sample_graph.name)
#     assert is_binary(Map.get(delete_result.statistics, "Query internal execution time"))
#   end

#   test "gets results from call procedures" do
#     {:ok, conn} = Redix.start_link("redis://localhost:6379")

#     sample_graph = build_sample_graph()

#     {:ok, commit_result} = RedisGraph.commit(conn, sample_graph)
#     %QueryResult{} = commit_result

#     assert Map.get(commit_result.statistics, "Nodes created") == "2"
#     assert Map.get(commit_result.statistics, "Relationships created") == "1"

#     {:ok, labels_result} = RedisGraph.labels(conn, sample_graph.name)

#     labels =
#       labels_result
#       |> Enum.at(1)
#       |> Enum.map(fn element -> element |> Enum.at(0) |> Enum.at(1) end)

#     assert "person" in labels
#     assert "country" in labels

#     {:ok, property_keys_result} = RedisGraph.property_keys(conn, sample_graph.name)

#     property_keys =
#       property_keys_result
#       |> Enum.at(1)
#       |> Enum.map(fn element -> element |> Enum.at(0) |> Enum.at(1) end)

#     assert "age" in property_keys
#     assert "gender" in property_keys
#     assert "name" in property_keys
#     assert "status" in property_keys

#     {:ok, relationship_types_result} = RedisGraph.relationship_types(conn, sample_graph.name)

#     relationship_types =
#       relationship_types_result
#       |> Enum.at(1)
#       |> Enum.map(fn element -> element |> Enum.at(0) |> Enum.at(1) end)

#     assert "visited" in relationship_types

#     {:ok, delete_result} = RedisGraph.delete(conn, sample_graph.name)
#     assert is_binary(Map.get(delete_result.statistics, "Query internal execution time"))
#   end

#   test "merges the pattern into the graph" do
#     {:ok, conn} = Redix.start_link(@redis_address)

#     sample_graph = build_sample_graph()

#     {:ok, commit_result} = RedisGraph.commit(conn, sample_graph)
#     %QueryResult{} = commit_result

#     p = "(:person { name: 'Michael Douglas' })"
#     {:ok, merge_result} = RedisGraph.merge(conn, sample_graph.name, p)
#     assert Map.get(merge_result.statistics, "Nodes created") == "1"

#     {:ok, delete_result} = RedisGraph.delete(conn, sample_graph.name)
#     assert is_binary(Map.get(delete_result.statistics, "Query internal execution time"))
#   end
# end
