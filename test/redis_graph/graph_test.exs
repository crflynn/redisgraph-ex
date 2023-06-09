defmodule RedisGraph.GraphTest do
  alias RedisGraph.Graph

  use ExUnit.Case

  describe "Graph" do
    test "creates a new graph" do
      mygraph = Graph.new(%{name: "social"})
      assert is_struct(mygraph)
    end

    test "fail to create a graph because incorrect parameter is provided" do
      # mygraph = Graph.new("social")
      assert_raise(FunctionClauseError, fn -> Graph.new("social") end)
    end
  end
end
