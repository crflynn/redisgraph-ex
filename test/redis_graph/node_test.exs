defmodule RedisGraph.NodeTest do
  alias RedisGraph.Node

  use ExUnit.Case

  describe "Node:" do
    test "creates a new Node with labels and properties" do
      mynode = Node.new(%{label: "person", properties: %{name: "John Doe"}})
      assert is_struct(mynode, Node)
    end

    test "generating alias when not provided on ititalization" do
      mynode = Node.new(%{labels: ["person"], properties: %{name: "John Doe"}})
      alias = Map.get(mynode, :alias)
      assert is_atom(alias)
    end

    test "not generating new alias is not generated if one is already present" do
      mynode = Node.new(%{labels: ["person"], properties: %{name: "John Doe"}})
      orig_alias = Map.get(mynode, :alias)
      %{alias: new_alias} = Node.set_alias_if_nil(mynode)
      assert orig_alias == new_alias
    end

    test "compares two Nodes correctly" do
      # different ids
      mynode = Node.new(%{id: 1, alias: "john", label: "person", properties: %{name: "John Doe"}})

      othernode =
        Node.new(%{id: 2, alias: "john", label: "person", properties: %{name: "John Doe"}})

      assert not Node.compare(mynode, othernode)

      # different alias
      mynode = Node.new(%{alias: :n, labels: ["person"], properties: %{name: "John Doe"}})
      othernode = Node.new(%{alias: :m, labels: ["human"], properties: %{name: "John Doe"}})

      assert not Node.compare(mynode, othernode)

      # different labels sizes
      mynode =
        Node.new(%{alias: :n, labels: ["person", "student"], properties: %{name: "John Doe"}})

      othernode = Node.new(%{alias: :n, labels: ["person"], properties: %{name: "John Doe"}})

      assert not Node.compare(mynode, othernode)

      # different labels
      mynode = Node.new(%{alias: :n, labels: ["person"], properties: %{name: "John Doe"}})
      othernode = Node.new(%{alias: :n, labels: ["human"], properties: %{name: "John Doe"}})

      assert not Node.compare(mynode, othernode)

      # different properties sizes
      mynode = Node.new(%{alias: :n, labels: ["person"], properties: %{name: "John Doe"}})

      othernode =
        Node.new(%{alias: :n, labels: ["person"], properties: %{name: "John Doe", age: 25}})

      assert not Node.compare(mynode, othernode)

      # different properties
      mynode = Node.new(%{alias: :n, labels: ["person"], properties: %{name: "John Doe"}})
      othernode = Node.new(%{alias: :n, labels: ["person"], properties: %{name: "Jane Doe"}})

      assert not Node.compare(mynode, othernode)

      # same constructed node
      mynode = Node.new(%{alias: :n, labels: ["person"], properties: %{name: "John Doe"}})
      othernode = Node.new(%{alias: :n, labels: ["person"], properties: %{name: "John Doe"}})

      assert Node.compare(mynode, othernode)
    end
  end
end
