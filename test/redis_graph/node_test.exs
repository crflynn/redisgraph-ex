defmodule RedisGraph.NodeTest do
  alias RedisGraph.Node

  use ExUnit.Case

  test "creates a new Node" do
    mynode = Node.new(%{label: "person", properties: %{name: "John Doe"}})
    assert %Node{} = mynode
  end

  test "sets the Node alias" do
    mynode = Node.new(%{label: "person", properties: %{name: "John Doe"}})
    assert is_nil(mynode.alias)

    # assign the alias
    mynode = Node.set_alias_if_nil(mynode)
    assert not is_nil(mynode.alias)

    # ensure calling again does not modify the alias
    %{alias: orig_alias} = mynode
    %{alias: new_alias} = Node.set_alias_if_nil(mynode)
    assert orig_alias == new_alias
  end

  test "gets the properties to a string" do
    mynode = Node.new(%{label: "person", properties: %{name: "John Doe"}})
    props = Node.properties_to_string(mynode)

    assert props == "{name:'John Doe'}"
  end

  test "gets a query string for the node" do
    mynode = Node.new(%{alias: "john", label: "person", properties: %{name: "John Doe"}})
    query_string = Node.to_query_string(mynode)

    assert query_string == "(john:person{name:'John Doe'})"
  end

  test "compares two Nodes correctly" do
    # different ids
    mynode = Node.new(%{id: 1, alias: "john", label: "person", properties: %{name: "John Doe"}})

    othernode =
      Node.new(%{id: 2, alias: "john", label: "person", properties: %{name: "John Doe"}})

    assert not Node.compare(mynode, othernode)

    # different labels
    mynode = Node.new(%{label: "person", properties: %{name: "John Doe"}})
    othernode = Node.new(%{label: "human", properties: %{name: "John Doe"}})

    assert not Node.compare(mynode, othernode)

    # different properties sizes
    mynode = Node.new(%{label: "person", properties: %{name: "John Doe"}})
    othernode = Node.new(%{label: "person", properties: %{name: "John Doe", age: 25}})

    assert not Node.compare(mynode, othernode)

    # different properties
    mynode = Node.new(%{label: "person", properties: %{name: "John Doe"}})
    othernode = Node.new(%{label: "person", properties: %{name: "Jane Doe"}})

    assert not Node.compare(mynode, othernode)

    # same constructed node
    mynode = Node.new(%{label: "person", properties: %{name: "John Doe"}})
    othernode = Node.new(%{label: "person", properties: %{name: "John Doe"}})

    assert Node.compare(mynode, othernode)
  end
end
