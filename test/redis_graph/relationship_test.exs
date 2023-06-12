defmodule RedisGraph.RelationshipTest do
  alias RedisGraph.{Node, Relationship}

  use ExUnit.Case, async: true

  describe "Relationship:" do
    test "create a new Relationship" do
      src_node = Node.new(%{labels: ["person"], properties: %{name: "John Doe"}})
      dest_node = Node.new(%{labels: ["place"], properties: %{name: "Japan"}})

      myrelationship =
        Relationship.new(%{
          alias: :r,
          src_node: src_node,
          dest_node: dest_node,
          type: "visits",
          properties: %{purpose: "pleasure"}
        })

      assert is_struct(myrelationship, Relationship)
    end

    test "generating alias when not provided on ititalization" do
      src_node = Node.new(%{labels: ["person"], properties: %{name: "John Doe"}})
      dest_node = Node.new(%{labels: ["place"], properties: %{name: "Japan"}})

      myrelationship =
        Relationship.new(%{
          src_node: src_node,
          dest_node: dest_node,
          type: "visits",
          properties: %{purpose: "pleasure"}
        })

      alias = Map.get(myrelationship, :alias)
      assert is_atom(alias)
    end

    test "not generating new alias is not generated if one is already present" do
      src_node = Node.new(%{labels: ["person"], properties: %{name: "John Doe"}})
      dest_node = Node.new(%{labels: ["place"], properties: %{name: "Japan"}})

      myrelationship =
        Relationship.new(%{
          alias: :r,
          src_node: src_node,
          dest_node: dest_node,
          type: "visits",
          properties: %{purpose: "pleasure"}
        })

      orig_alias = Map.get(myrelationship, :alias)
      %{alias: new_alias} = Relationship.set_alias_if_nil(myrelationship)
      assert orig_alias == new_alias
    end

    test "fail to create relationship because type is not provided" do
      src_node = Node.new(%{labels: ["person"], properties: %{name: "John Doe"}})
      dest_node = Node.new(%{labels: ["place"], properties: %{name: "Japan"}})

      assert_raise(FunctionClauseError, fn ->
        Relationship.new(%{
          src_node: src_node,
          dest_node: dest_node,
          properties: %{purpose: "pleasure"}
        })
      end)
    end

    test "compares two relationships correctly" do
      src_node = Node.new(%{labels: ["person"], properties: %{name: "John Doe"}})
      dest_node = Node.new(%{labels: ["place"], properties: %{name: "Japan"}})

      # different ids
      myrelationship =
        Relationship.new(%{
          id: "a",
          src_node: src_node,
          dest_node: dest_node,
          type: "visits",
          properties: %{purpose: "pleasure"}
        })

      otherrelationship =
        Relationship.new(%{
          id: "b",
          src_node: src_node,
          dest_node: dest_node,
          type: "visits",
          properties: %{purpose: "pleasure"}
        })

      assert not Relationship.compare(myrelationship, otherrelationship)

      # different source nodes
      other_node = Node.new(%{labels: ["food"], properties: %{name: "Apple"}})

      myrelationship =
        Relationship.new(%{
          src_node: src_node,
          dest_node: dest_node,
          type: "visits",
          properties: %{purpose: "pleasure"}
        })

      otherrelationship =
        Relationship.new(%{
          src_node: other_node,
          dest_node: dest_node,
          type: "visits",
          properties: %{purpose: "pleasure"}
        })

      assert not Relationship.compare(myrelationship, otherrelationship)

      # different destination nodes
      myrelationship =
        Relationship.new(%{
          src_node: src_node,
          dest_node: dest_node,
          type: "visits",
          properties: %{purpose: "pleasure"}
        })

      otherrelationship =
        Relationship.new(%{
          src_node: src_node,
          dest_node: other_node,
          type: "visits",
          properties: %{purpose: "pleasure"}
        })

      assert not Relationship.compare(myrelationship, otherrelationship)

      # different types
      myrelationship =
        Relationship.new(%{
          src_node: src_node,
          type: "a",
          dest_node: dest_node,
          properties: %{purpose: "pleasure"}
        })

      otherrelationship =
        Relationship.new(%{
          src_node: src_node,
          type: "b",
          dest_node: dest_node,
          properties: %{purpose: "pleasure"}
        })

      assert not Relationship.compare(myrelationship, otherrelationship)

      # different properties sizes
      myrelationship =
        Relationship.new(%{
          src_node: src_node,
          dest_node: dest_node,
          type: "visits",
          properties: %{purpose: "pleasure"}
        })

      otherrelationship =
        Relationship.new(%{
          src_node: src_node,
          dest_node: dest_node,
          type: "visits",
          properties: %{purpose: "pleasure", enjoyable: "very"}
        })

      assert not Relationship.compare(myrelationship, otherrelationship)

      # different properties
      myrelationship =
        Relationship.new(%{
          src_node: src_node,
          dest_node: dest_node,
          type: "visits",
          properties: %{purpose: "pleasure"}
        })

      otherrelationship =
        Relationship.new(%{
          src_node: src_node,
          dest_node: dest_node,
          type: "visits",
          properties: %{purpose: "business"}
        })

      assert not Relationship.compare(myrelationship, otherrelationship)

      # same relationships
      myrelationship =
        Relationship.new(%{
          src_node: src_node,
          dest_node: dest_node,
          type: "visits",
          properties: %{purpose: "pleasure"}
        })

      otherrelationship =
        Relationship.new(%{
          src_node: src_node,
          dest_node: dest_node,
          type: "visits",
          properties: %{purpose: "pleasure"}
        })

      assert Relationship.compare(myrelationship, otherrelationship)
    end
  end
end
